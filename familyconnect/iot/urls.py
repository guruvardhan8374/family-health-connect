from django.urls import path
from .views import IoTManualSyncView, SyncStatusView

urlpatterns = [
    path('sync/', IoTManualSyncView.as_view(), name='manual-sync'),
    path('history/', SyncStatusView.as_view(), name='sync-history'),
]
