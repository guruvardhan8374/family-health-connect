from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Notification, Reminder
from .serializers import NotificationSerializer, ReminderSerializer
from .permissions import IsNotificationOwner

from django.utils import timezone

class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated, IsNotificationOwner]
    filterset_fields = ['is_read', 'type', 'priority']
    search_fields = ['title', 'message']

    def get_queryset(self):
        qs = Notification.objects.filter(user=self.request.user).order_by('-created_at')
        notif_type = self.request.query_params.get('type')
        if notif_type:
            qs = qs.filter(type__iexact=notif_type)
        return qs

    def perform_create(self, serializer):
        instance = serializer.save(user=self.request.user)
        # Push live event
        try:
            from .services import send_fcm_notification
            from sync.signals import _push
            payload = {
                'id': instance.id,
                'type': instance.type,
                'title': instance.title,
                'message': instance.message,
                'priority': instance.priority,
                'data': instance.data,
                'is_read': instance.is_read,
                'created_at': instance.created_at.isoformat(),
            }
            _push(instance.user_id, 'notification.new', 'push', payload)
            send_fcm_notification(instance.user, instance.title, instance.message, instance.data)
        except Exception:
            pass

    @action(detail=False, methods=['get'], url_path='unread-count')
    def unread_count(self, request):
        count = Notification.objects.filter(user=request.user, is_read=False).count()
        return Response({'unread_count': count})

    @action(detail=True, methods=['post'], url_path='mark-read')
    def mark_read(self, request, pk=None):
        notification = self.get_object()
        notification.is_read = True
        notification.read_at = timezone.now()
        notification.save(update_fields=['is_read', 'read_at'])
        return Response({'status': 'notification marked as read', 'notification': NotificationSerializer(notification).data})

    @action(detail=False, methods=['post'], url_path='mark-all-read')
    def mark_all_read(self, request):
        Notification.objects.filter(user=request.user, is_read=False).update(is_read=True, read_at=timezone.now())
        return Response({'status': 'all notifications marked as read'})

    @action(detail=False, methods=['delete', 'post'], url_path='delete-all')
    def delete_all(self, request):
        deleted_count, _ = Notification.objects.filter(user=request.user).delete()
        return Response({'status': 'all notifications deleted', 'deleted_count': deleted_count}, status=status.HTTP_200_OK)

class ReminderViewSet(viewsets.ModelViewSet):
    serializer_class = ReminderSerializer
    permission_classes = [permissions.IsAuthenticated, IsNotificationOwner]
    filterset_fields = ['is_active', 'reminder_type']

    def get_queryset(self):
        return Reminder.objects.filter(user=self.request.user).order_by('time')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
