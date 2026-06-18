from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from datetime import timedelta
from django.db.models import Avg, Sum, Max, Q

from .models import HealthRecord
from .serializers import HealthRecordSerializer
from .permissions import IsOwnerOrFamilyAdmin
from .services import (
    get_health_score, detect_anomalies, generate_health_suggestions, 
    get_weekly_analytics, calculate_bmi
)
from family.models import FamilyMembership

class HealthRecordViewSet(viewsets.ModelViewSet):
    serializer_class = HealthRecordSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrFamilyAdmin]
    filterset_fields = ['recorded_date']
    ordering_fields = ['recorded_date', 'created_at']

    def get_queryset(self):
        user = self.request.user
        
        # Super admin sees everything
        if user.role in ['SUPER_ADMIN', 'ORG_ADMIN']:
            return HealthRecord.objects.all().order_by('-recorded_date')
            
        # Get families where the user is an admin
        admin_families = FamilyMembership.objects.filter(
            user=user, 
            is_admin=True, 
            is_approved=True
        ).values_list('family_group_id', flat=True)
        
        # Get users belonging to these families
        accessible_member_ids = FamilyMembership.objects.filter(
            family_group_id__in=admin_families, 
            is_approved=True
        ).values_list('user_id', flat=True)
        
        # User can see their own records OR family admin can see their members' records
        return HealthRecord.objects.filter(
            Q(user=user) | Q(user_id__in=accessible_member_ids)
        ).distinct().order_by('-recorded_date')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=False, methods=['get'], url_path='weekly-summary')
    def weekly_summary(self, request):
        target_user_id = request.query_params.get('user_id')
        target_user = request.user
        
        if target_user_id:
            # Check permission to view this user's summary
            if str(target_user_id) != str(request.user.id):
                admin_families = FamilyMembership.objects.filter(user=request.user, is_admin=True, is_approved=True).values_list('family_group_id', flat=True)
                is_allowed = FamilyMembership.objects.filter(user_id=target_user_id, family_group_id__in=admin_families, is_approved=True).exists()
                if not is_allowed and not request.user.role in ['SUPER_ADMIN', 'ORG_ADMIN']:
                    return Response({"error": "You do not have permission to view this user's records"}, status=status.HTTP_403_FORBIDDEN)
                from users.models import CustomUser
                try:
                    target_user = CustomUser.objects.get(id=target_user_id)
                except CustomUser.DoesNotExist:
                    return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)

        analytics = get_weekly_analytics(target_user)
        return Response(analytics)

    @action(detail=False, methods=['get'], url_path='health-intelligence')
    def health_intelligence(self, request):
        target_user_id = request.query_params.get('user_id')
        target_user = request.user
        
        if target_user_id:
            if str(target_user_id) != str(request.user.id):
                admin_families = FamilyMembership.objects.filter(user=request.user, is_admin=True, is_approved=True).values_list('family_group_id', flat=True)
                is_allowed = FamilyMembership.objects.filter(user_id=target_user_id, family_group_id__in=admin_families, is_approved=True).exists()
                if not is_allowed and not request.user.role in ['SUPER_ADMIN', 'ORG_ADMIN']:
                    return Response({"error": "You do not have permission to view this user's records"}, status=status.HTTP_403_FORBIDDEN)
                from users.models import CustomUser
                try:
                    target_user = CustomUser.objects.get(id=target_user_id)
                except CustomUser.DoesNotExist:
                    return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)

        score = get_health_score(target_user)
        anomalies = detect_anomalies(target_user)
        suggestions = generate_health_suggestions(target_user)
        
        return Response({
            "health_score": score,
            "anomalies": anomalies,
            "suggestions": suggestions
        })

    @action(detail=False, methods=['get'], url_path='trends')
    def trends(self, request):
        target_user = request.user
        target_user_id = request.query_params.get('user_id')
        
        if target_user_id:
            if str(target_user_id) != str(request.user.id):
                admin_families = FamilyMembership.objects.filter(user=request.user, is_admin=True, is_approved=True).values_list('family_group_id', flat=True)
                is_allowed = FamilyMembership.objects.filter(user_id=target_user_id, family_group_id__in=admin_families, is_approved=True).exists()
                if not is_allowed and not request.user.role in ['SUPER_ADMIN', 'ORG_ADMIN']:
                    return Response({"error": "You do not have permission"}, status=status.HTTP_403_FORBIDDEN)
                from users.models import CustomUser
                try:
                    target_user = CustomUser.objects.get(id=target_user_id)
                except CustomUser.DoesNotExist:
                    return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)

        # Get last 15 days trend data
        fifteen_days_ago = timezone.now().date() - timedelta(days=15)
        records = HealthRecord.objects.filter(user=target_user, recorded_date__gte=fifteen_days_ago).order_by('recorded_date')
        
        serializer = self.get_serializer(records, many=True)
        return Response(serializer.data)    