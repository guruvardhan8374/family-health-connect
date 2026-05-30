from rest_framework import viewsets, permissions
from .models import HealthMetric, HealthAlert
from .serializers import HealthMetricSerializer, HealthAlertSerializer

class HealthMetricViewSet(viewsets.ModelViewSet):
    serializer_class = HealthMetricSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # In a real app, logic to allow family admins to see member health
        # For MVP, users see their own metrics
        return HealthMetric.objects.filter(user=self.request.user)

class HealthAlertViewSet(viewsets.ModelViewSet):
    serializer_class = HealthAlertSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return HealthAlert.objects.filter(user=self.request.user)
