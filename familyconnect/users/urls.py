from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    UserViewSet, LocationHistoryViewSet, RegisterView, VerifyOTPView,
    PasswordResetRequestView, PasswordResetConfirmView, UserProfileView,
    UserSettingsViewSet, ChangePasswordView, DebugDBView, ListUsersDebugView, GoogleAuthView
)

router = DefaultRouter()
router.register(r'users', UserViewSet, basename='user')
router.register(r'locations', LocationHistoryViewSet, basename='location')
router.register(r'settings', UserSettingsViewSet, basename='user-settings')

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('google-login/', GoogleAuthView.as_view(), name='google-login'),
    path('verify-otp/', VerifyOTPView.as_view(), name='verify-otp'),
    path('debug-db/', DebugDBView.as_view(), name='debug-db'),
    path('debug-users/', ListUsersDebugView.as_view(), name='debug-users'),
    path('password-reset/', PasswordResetRequestView.as_view(), name='password-reset-request'),
    path('password-reset-confirm/', PasswordResetConfirmView.as_view(), name='password-reset-confirm'),
    path('profile/', UserProfileView.as_view(), name='user-profile'),
    path('change-password/', ChangePasswordView.as_view(), name='change-password'),
    path('', include(router.urls)),
]
