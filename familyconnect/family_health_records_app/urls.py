from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import HealthRecordViewSet

router = DefaultRouter()

router.register(
    r'health-records',
    HealthRecordViewSet,
    basename='health-records'
)

urlpatterns = [
    path('', include(router.urls)),
]