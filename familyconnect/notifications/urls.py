from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import NotificationViewSet, ReminderViewSet

router = DefaultRouter()
router.register(r'reminders', ReminderViewSet, basename='reminder')
router.register(r'', NotificationViewSet, basename='notification')

urlpatterns = [
    path('', include(router.urls)),
]
