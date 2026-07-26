from rest_framework import viewsets, permissions, status
from rest_framework.views import APIView
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from django.db.models import Q

from .models import EmergencyContact, SOSAlert, NearbyHospital
from .serializers import EmergencyContactSerializer, SOSAlertSerializer, NearbyHospitalSerializer
from .permissions import CanManageEmergencyContacts
from .services import get_vitals_snapshot, notify_family_members, get_nearby_police_stations
from family.models import FamilyMembership


class EmergencyContactViewSet(viewsets.ModelViewSet):
    serializer_class = EmergencyContactSerializer
    permission_classes = [permissions.IsAuthenticated, CanManageEmergencyContacts]

    def get_queryset(self):
        return EmergencyContact.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class SOSAlertViewSet(viewsets.ModelViewSet):
    serializer_class = SOSAlertSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        
        # Super admin sees all alerts
        if user.role in ['SUPER_ADMIN', 'ORG_ADMIN']:
            return SOSAlert.objects.all().order_by('-triggered_at')
            
        # Get family groups user is part of
        user_family_groups = FamilyMembership.objects.filter(
            user=user, 
            is_approved=True
        ).values_list('family_group_id', flat=True)
        
        # Get all users in those family groups
        family_member_ids = FamilyMembership.objects.filter(
            family_group_id__in=user_family_groups,
            is_approved=True
        ).values_list('user_id', flat=True)
        
        # Return alerts triggered by self or family members
        return SOSAlert.objects.filter(
            Q(user=user) | Q(user_id__in=family_member_ids)
        ).distinct().order_by('-triggered_at')

    def perform_create(self, serializer):
        vitals = get_vitals_snapshot(self.request.user)
        serializer.save(user=self.request.user, vitals_snapshot=vitals)

    @action(detail=False, methods=['post'])
    def trigger(self, request):
        lat = request.data.get('latitude') or request.data.get('location_lat')
        lng = request.data.get('longitude') or request.data.get('location_lng')
        message = request.data.get('message', 'Emergency! I need help immediately.')
        
        vitals = get_vitals_snapshot(request.user)
        
        alert = SOSAlert.objects.create(
            user=request.user,
            location_lat=lat,
            location_lng=lng,
            message=message,
            status='ACTIVE',
            is_resolved=False,
            vitals_snapshot=vitals
        )
        
        # Broadcast push/in-app notifications to family
        notified_count = notify_family_members(alert)
        
        return Response({
            "message": "SOS Alert triggered successfully and family notified.",
            "notified_members_count": notified_count,
            "alert": SOSAlertSerializer(alert).data
        }, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def resolve(self, request, pk=None):
        alert = self.get_object()
        
        # Only the triggerer or a family admin can resolve the alert
        is_admin_of_any_shared_family = False
        user_admin_families = FamilyMembership.objects.filter(user=request.user, is_admin=True, is_approved=True).values_list('family_group_id', flat=True)
        if user_admin_families.exists():
            is_admin_of_any_shared_family = FamilyMembership.objects.filter(
                user=alert.user, 
                family_group_id__in=user_admin_families, 
                is_approved=True
            ).exists()
            
        if alert.user != request.user and not is_admin_of_any_shared_family and not request.user.role in ['SUPER_ADMIN', 'ORG_ADMIN']:
            return Response({"error": "You do not have permission to resolve this SOS alert"}, status=status.HTTP_403_FORBIDDEN)
            
        status_value = request.data.get('status', 'RESOLVED')
        if status_value not in ['RESOLVED', 'FALSE_ALARM']:
            status_value = 'RESOLVED'
            
        alert.status = status_value
        alert.is_resolved = True
        alert.resolved_at = timezone.now()
        alert.save()
        
        # Send system notification about resolution
        user_family_groups = FamilyMembership.objects.filter(user=alert.user, is_approved=True).values_list('family_group_id', flat=True)
        family_members = FamilyMembership.objects.filter(family_group_id__in=user_family_groups, is_approved=True).exclude(user=request.user).select_related('user')
        
        from notifications.services import create_notification
        for member in family_members:
            create_notification(
                user=member.user,
                type='SYSTEM',
                title='SOS Alert Resolved',
                message=f"The SOS alert triggered by {alert.user.username} has been marked as {status_value.replace('_', ' ').title()}.",
                priority='HIGH'
            )
            
        return Response({"status": f"Alert marked as {status_value}", "alert": SOSAlertSerializer(alert).data})

    @action(detail=False, methods=['get'], url_path='active')
    def active_alerts(self, request):
        user_family_groups = FamilyMembership.objects.filter(user=request.user, is_approved=True).values_list('family_group_id', flat=True)
        family_member_ids = FamilyMembership.objects.filter(family_group_id__in=user_family_groups, is_approved=True).values_list('user_id', flat=True)
        
        active_alerts = SOSAlert.objects.filter(
            Q(user_id__in=family_member_ids) | Q(user=request.user),
            status='ACTIVE'
        ).distinct().order_by('-triggered_at')
        
        serializer = self.get_serializer(active_alerts, many=True)
        return Response(serializer.data)

class NearbyHospitalViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = NearbyHospital.objects.all().order_by('distance_km')
    serializer_class = NearbyHospitalSerializer
    permission_classes = [permissions.IsAuthenticated]

class NearbyPoliceView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            lat = float(request.query_params.get('lat', 12.9716))
            lng = float(request.query_params.get('lng', 77.5946))
        except (TypeError, ValueError):
            lat, lng = 12.9716, 77.5946

        stations = get_nearby_police_stations(lat, lng)
        return Response({
            "count": len(stations),
            "user_location": {"latitude": lat, "longitude": lng},
            "police_stations": stations
        }, status=status.HTTP_200_OK)
