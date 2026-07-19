from django.urls import path
from .views import (
    AIAssistantHistoryView,
    AIAssistantHistoryClearView,
    PendingSyncView,
)

urlpatterns = [
    path('ai-history/', AIAssistantHistoryView.as_view(), name='ai-history'),
    path('ai-history/clear/', AIAssistantHistoryClearView.as_view(), name='ai-history-clear'),
    path('pending/', PendingSyncView.as_view(), name='pending-sync'),
]
