from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import permissions, generics
from django.contrib.auth import get_user_model
from family_health_records_app.models import HealthRecord
from health.models import HealthMetric, HealthAlert
from emergency.models import SOSAlert
from audit.models import AuditLog
from django.db.models import Count, Avg
from django.db.models.functions import TruncDate
from datetime import timedelta
from django.utils import timezone
from audit.serializers import AuditLogSerializer

User = get_user_model()

class SystemStatsView(APIView):
    permission_classes = [permissions.IsAdminUser]

    def get(self, request):
        now = timezone.now()
        last_24h = now - timedelta(hours=24)
        
        stats = {
            "total_users": User.objects.count(),
            "active_users_24h": User.objects.filter(last_login__gte=last_24h).count(),
            "total_health_records": HealthRecord.objects.count(),
            "sos_alerts_24h": SOSAlert.objects.filter(triggered_at__gte=last_24h).count(),
            "vitals_summary": {
                "avg_heart_rate": HealthRecord.objects.aggregate(Avg('heart_rate'))['heart_rate__avg'] or 0.0,
                "avg_oxygen": HealthRecord.objects.aggregate(Avg('oxygen_level'))['oxygen_level__avg'] or 0.0,
            },
            "alerts_by_status": HealthAlert.objects.values('is_read').annotate(count=Count('id'))
        }
        return Response(stats)

class UserGrowthView(APIView):
    permission_classes = [permissions.IsAdminUser]

    def get(self, request):
        # TruncDate is compatible with SQLite and Postgres
        growth = User.objects.annotate(day=TruncDate('date_joined')).values('day').annotate(count=Count('id')).order_by('day')
        return Response(growth)

class HealthAnalyticsSummaryView(APIView):
    permission_classes = [permissions.IsAdminUser]

    def get(self, request):
        summary = HealthRecord.objects.aggregate(
            avg_hr=Avg('heart_rate'),
            avg_o2=Avg('oxygen_level'),
            avg_steps=Avg('steps'),
            avg_sleep=Avg('sleep_hours'),
            avg_water=Avg('water_intake')
        )
        return Response({
            "avg_heart_rate": round(summary['avg_hr'] or 0.0, 1),
            "avg_oxygen_level": round(summary['avg_o2'] or 0.0, 1),
            "avg_steps": round(summary['avg_steps'] or 0.0, 1),
            "avg_sleep_hours": round(summary['avg_sleep'] or 0.0, 1),
            "avg_water_intake": round(summary['avg_water'] or 0.0, 1)
        })

class AuditLogListView(generics.ListAPIView):
    queryset = AuditLog.objects.all().select_related('user').order_by('-timestamp')
    serializer_class = AuditLogSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['action', 'user__username']
    search_fields = ['resource', 'ip_address', 'details']
