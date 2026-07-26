from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.contrib.auth import update_session_auth_hash
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError

from .models import (
    UserProfileSettings, NotificationSettings,
    PrivacySettings, ThemeSettings, AccountSettings
)
from .serializers import (
    UserProfileSettingsSerializer, NotificationSettingsSerializer,
    PrivacySettingsSerializer, ThemeSettingsSerializer, AccountSettingsSerializer
)
from .permissions import IsOwner


class BaseSettingsView(generics.RetrieveUpdateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsOwner]

    def get_object(self):
        model = self.serializer_class.Meta.model
        obj, created = model.objects.get_or_create(user=self.request.user)
        return obj

    def put(self, request, *args, **kwargs):
        kwargs['partial'] = True
        return self.update(request, *args, **kwargs)


import logging
import traceback

logger = logging.getLogger(__name__)


class UserProfileSettingsView(BaseSettingsView):
    serializer_class = UserProfileSettingsSerializer

    def put(self, request, *args, **kwargs):
        kwargs['partial'] = True
        logger.info(f"[ProfileUpdate] PUT /api/v1/settings/profile/ by user {request.user.username} ({request.user.id}): data={request.data}")
        try:
            response = super().put(request, *args, **kwargs)
            logger.info(f"[ProfileUpdate] Profile updated successfully for user {request.user.username}")
            return response
        except Exception as e:
            logger.error(f"[ProfileUpdate EXCEPTION] {e}\n{traceback.format_exc()}")
            raise e


class NotificationSettingsView(BaseSettingsView):
    serializer_class = NotificationSettingsSerializer


class PrivacySettingsView(BaseSettingsView):
    serializer_class = PrivacySettingsSerializer


class ThemeSettingsView(BaseSettingsView):
    serializer_class = ThemeSettingsSerializer


class AccountSettingsView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = AccountSettingsSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwner]

    def get_object(self):
        obj, created = AccountSettings.objects.get_or_create(user=self.request.user)
        return obj

    def update(self, request, *args, **kwargs):
        # Support updating settings toggles normally
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        
        # Check if a password change is also requested
        old_password = request.data.get('old_password')
        new_password = request.data.get('new_password')
        confirm_password = request.data.get('confirm_password')

        if old_password or new_password or confirm_password:
            if not (old_password and new_password and confirm_password):
                return Response(
                    {"error": "To change password, old_password, new_password, and confirm_password are all required."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            if new_password != confirm_password:
                return Response(
                    {"confirm_password": ["New passwords do not match."]},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            user = request.user
            if not user.check_password(old_password):
                return Response(
                    {"old_password": ["Incorrect password."]},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            try:
                validate_password(new_password, user)
            except ValidationError as e:
                return Response(
                    {"new_password": list(e.messages)},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            user.set_password(new_password)
            user.save()
            update_session_auth_hash(request, user)

        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)

        return Response(serializer.data)

    def delete(self, request, *args, **kwargs):
        # Perform account deletion
        user = request.user
        user.delete()
        return Response(
            {"message": "Your account has been deleted successfully."},
            status=status.HTTP_200_OK
        )
