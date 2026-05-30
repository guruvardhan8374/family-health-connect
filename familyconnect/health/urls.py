from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import HealthMetricViewSet, HealthAlertViewSet

router = DefaultRouter()
router.register(r'metrics', HealthMetricViewSet, basename='healthmetric')
router.register(r'alerts', HealthAlertViewSet, basename='healthalert')

urlpatterns = [
    path('', include(router.urls)),
]
