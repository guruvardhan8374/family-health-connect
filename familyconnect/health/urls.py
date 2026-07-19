from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    HealthSnapshotViewSet, HealthGoalViewSet,
    HealthMetricViewSet, HealthAlertViewSet,
    HealthSummaryView, FamilyHealthSummaryView,
    HealthSummaryTodayView,
)

router = DefaultRouter()
router.register(r'snapshots',  HealthSnapshotViewSet, basename='health-snapshot')
router.register(r'goals',      HealthGoalViewSet,     basename='health-goal')
router.register(r'metrics',    HealthMetricViewSet,   basename='healthmetric')
router.register(r'alerts',     HealthAlertViewSet,    basename='healthalert')

urlpatterns = [
    path('', include(router.urls)),
    path('summary/today/',  HealthSummaryTodayView.as_view(),  name='health-summary-today'),
    path('summary/',        HealthSummaryView.as_view(),       name='health-summary'),
    path('family-summary/', FamilyHealthSummaryView.as_view(), name='family-health-summary'),
]
