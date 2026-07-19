import logging
from django.utils import timezone
from django.conf import settings as django_settings
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.generics import ListCreateAPIView

from .models import AIAssistantHistory, PendingSyncLog
from .serializers import (
    AIAssistantHistorySerializer,
    PendingSyncSerializer,
)

logger = logging.getLogger(__name__)

# ── AI Assistant History ────────────────────────────────────────────────────────

class AIAssistantHistoryView(ListCreateAPIView):
    """
    GET  /api/v1/sync/ai-history/  — returns the last 100 turns for this user
    POST /api/v1/sync/ai-history/  — saves a new turn (role + content)
    """
    serializer_class = AIAssistantHistorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return AIAssistantHistory.objects.filter(
            user=self.request.user
        ).order_by('-created_at')[:100]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class AIAssistantHistoryClearView(APIView):
    """DELETE /api/v1/sync/ai-history/clear/ — wipe all history for this user."""
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request):
        deleted_count, _ = AIAssistantHistory.objects.filter(user=request.user).delete()
        return Response({'deleted': deleted_count})


# ── Offline Pending Sync ────────────────────────────────────────────────────────

class PendingSyncView(APIView):
    """
    POST /api/v1/sync/pending/

    Accepts a JSON body:
    {
      "mutations": [
        { "endpoint": "/api/v1/health/snapshots/", "method": "POST", "payload": {...} },
        { "endpoint": "/api/v1/notifications/reminders/1/", "method": "PATCH", "payload": {...} }
      ]
    }

    Replays each mutation against the real Django URL resolver so that
    offline changes made on mobile or web are properly committed once
    the client comes back online.

    Returns a summary of which mutations succeeded and which failed.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = PendingSyncSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        mutations = serializer.validated_data['mutations']
        results = []

        for mutation in mutations:
            endpoint = mutation['endpoint']
            method = mutation['method'].upper()
            payload = mutation.get('payload', {})

            log = PendingSyncLog.objects.create(
                user=request.user,
                endpoint=endpoint,
                method=method,
                payload=payload,
            )

            try:
                result = self._replay(request, method, endpoint, payload)
                log.status = 'applied'
                log.applied_at = timezone.now()
                log.save(update_fields=['status', 'applied_at'])
                results.append({
                    'endpoint': endpoint,
                    'method': method,
                    'status': 'applied',
                    'response_status': result,
                })
            except Exception as e:
                log.status = 'failed'
                log.error_message = str(e)
                log.save(update_fields=['status', 'error_message'])
                results.append({
                    'endpoint': endpoint,
                    'method': method,
                    'status': 'failed',
                    'error': str(e),
                })

        applied = sum(1 for r in results if r['status'] == 'applied')
        failed = len(results) - applied

        return Response({
            'total': len(results),
            'applied': applied,
            'failed': failed,
            'results': results,
        })

    def _replay(self, original_request, method, endpoint, payload):
        """
        Internally replay a mutation by calling Django's URL resolver.
        Uses the same authenticated user from the original request.
        """
        from django.test import RequestFactory
        from django.urls import resolve, Resolver404
        import json

        # Strip leading /api/v1 if present — resolve needs the full path
        path = endpoint if endpoint.startswith('/') else f'/{endpoint}'

        try:
            match = resolve(path)
        except Resolver404:
            raise ValueError(f'Unknown endpoint: {path}')

        factory = RequestFactory()
        body = json.dumps(payload).encode('utf-8')

        method_map = {
            'POST': factory.post,
            'PUT': factory.put,
            'PATCH': factory.patch,
            'DELETE': factory.delete,
            'GET': factory.get,
        }

        make_request = method_map.get(method)
        if not make_request:
            raise ValueError(f'Unsupported HTTP method: {method}')

        if method in ('POST', 'PUT', 'PATCH'):
            fake_req = make_request(path, data=body, content_type='application/json')
        else:
            fake_req = make_request(path)

        # Attach auth
        fake_req.user = original_request.user
        fake_req.META.update({
            'HTTP_AUTHORIZATION': original_request.META.get('HTTP_AUTHORIZATION', ''),
        })

        view = match.func
        response = view(fake_req, *match.args, **match.kwargs)

        if hasattr(response, 'status_code') and response.status_code >= 400:
            raise ValueError(f'Replay returned HTTP {response.status_code}')

        return getattr(response, 'status_code', 200)
