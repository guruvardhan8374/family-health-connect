from django.urls import path
from .views import (
    UserProfileSettingsView, NotificationSettingsView,
    PrivacySettingsView, ThemeSettingsView, AccountSettingsView
)

urlpatterns = [
    path('profile/', UserProfileSettingsView.as_view(), name='settings-profile'),
    path('notifications/', NotificationSettingsView.as_view(), name='settings-notifications'),
    path('privacy/', PrivacySettingsView.as_view(), name='settings-privacy'),
    path('theme/', ThemeSettingsView.as_view(), name='settings-theme'),
    path('account/', AccountSettingsView.as_view(), name='settings-account'),
]
