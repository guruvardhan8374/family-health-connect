from django.urls import path
from .views import SystemStatsView, UserGrowthView, HealthAnalyticsSummaryView, AuditLogListView

urlpatterns = [
    path('stats/', SystemStatsView.as_view(), name='system-stats'),
    path('growth/', UserGrowthView.as_view(), name='user-growth'),
    path('health-summary/', HealthAnalyticsSummaryView.as_view(), name='admin-health-summary'),
    path('audit-logs/', AuditLogListView.as_view(), name='admin-audit-logs'),
]
