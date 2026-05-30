from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import EmergencyContactViewSet, SOSAlertViewSet, NearbyHospitalViewSet

router = DefaultRouter()
router.register(r'contacts', EmergencyContactViewSet, basename='emergency-contact')
router.register(r'alerts', SOSAlertViewSet, basename='sos-alert')
router.register(r'hospitals', NearbyHospitalViewSet, basename='nearby-hospital')

urlpatterns = [
    path('', include(router.urls)),
]
