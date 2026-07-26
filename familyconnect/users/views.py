from rest_framework import viewsets, permissions, status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.decorators import action
from rest_framework.parsers import MultiPartParser, FormParser
from django.utils import timezone
from django.conf import settings as django_settings
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.tokens import RefreshToken
from django.db import connection
import logging
import uuid
import os

logger = logging.getLogger(__name__)

from .models import CustomUser, LocationHistory, UserSettings
from .serializers import (
    UserSerializer, UserProfileSerializer, UserSettingsSerializer, 
    ChangePasswordSerializer, RegisterSerializer, LocationHistorySerializer
)
from .auth_serializers import EmailTokenObtainPairSerializer
from .permissions import IsOwnerOrAdmin
from .services import generate_otp, send_otp_email, verify_otp, hash_otp

class RegisterView(generics.CreateAPIView):
    queryset = CustomUser.objects.all()
    permission_classes = (permissions.AllowAny,)
    serializer_class = RegisterSerializer

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        
        # OTP email verification is disabled/removed. Set verified to True.
        user.is_otp_verified = True
        user.otp_code = None
        user.otp_created_at = None
        user.otp_failed_attempts = 0
        user.save()
        
        # Initialize default user settings
        UserSettings.objects.create(user=user)
        
        headers = self.get_success_headers(serializer.data)
        return Response({
            "message": "User registered successfully!",
            "user": UserSerializer(user).data,
            "email": user.email,
            "otp": None,
            "email_unverified": False
        }, status=status.HTTP_201_CREATED, headers=headers)

class SecureTokenObtainPairView(TokenObtainPairView):
    serializer_class = EmailTokenObtainPairSerializer

def get_family_info_for_user(user):
    """
    Retrieves the user's active family group membership details.
    """
    try:
        from family.models import FamilyMembership
        membership = FamilyMembership.objects.filter(
            user=user,
            is_approved=True
        ).select_related('family_group').order_by('-joined_at').first()

        if membership and membership.family_group:
            group = membership.family_group
            return {
                'has_family': True,
                'family_id': group.id,
                'family_name': group.name,
                'family_code': group.family_code,
                'role': membership.label or user.role,
                'is_admin': membership.is_admin,
                'status': membership.status
            }
    except Exception as e:
        logger.warning(f"Error fetching family info for user {user.id}: {e}")

    return {
        'has_family': False,
        'family_id': None,
        'family_name': None,
        'family_code': None,
        'role': getattr(user, 'role', 'MEMBER'),
        'is_admin': False,
        'status': None
    }

class GoogleAuthView(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        email_raw = request.data.get('email')
        username = request.data.get('username') or request.data.get('name')
        
        if not email_raw or not str(email_raw).strip():
            return Response({"error": "Email is required"}, status=status.HTTP_400_BAD_REQUEST)

        clean_email = str(email_raw).strip().lower()

        # Run deduplication on existing duplicate accounts with same email
        try:
            from users.utils import deduplicate_users_by_email
            deduplicate_users_by_email(clean_email)
        except Exception as e:
            logger.warning(f"Deduplication warning for {clean_email}: {e}")

        # Get or create CustomUser by case-insensitive email
        user = CustomUser.objects.filter(email__iexact=clean_email).order_by('id').first()
        if not user:
            clean_username = (username or clean_email.split('@')[0]).replace(' ', '_')
            if CustomUser.objects.filter(username__iexact=clean_username).exists():
                clean_username = f"{clean_username}_{uuid.uuid4().hex[:4]}"
            user = CustomUser.objects.create_user(
                username=clean_username,
                email=clean_email,
                role='MEMBER',
                is_otp_verified=True,
                is_active=True,
            )
            user.set_unusable_password()
            user.save()
            try:
                UserSettings.objects.get_or_create(user=user)
            except Exception:
                pass
        else:
            # Ensure Google user is marked active and verified
            if not user.is_otp_verified or not user.is_active:
                user.is_otp_verified = True
                user.is_active = True
                user.save(update_fields=['is_otp_verified', 'is_active'])

        family_info = get_family_info_for_user(user)

        # Issue Django SimpleJWT tokens
        refresh = RefreshToken.for_user(user)
        return Response({
            "message": "Google authentication successful",
            "access": str(refresh.access_token),
            "refresh": str(refresh),
            "user_id": user.id,
            "username": user.username,
            "email": user.email,
            "role": family_info['role'],
            "has_family": family_info['has_family'],
            "family_group": family_info if family_info['has_family'] else None
        }, status=status.HTTP_200_OK)

class VerifyOTPView(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        email = request.data.get('email')
        otp = request.data.get('otp')
        if not email or not otp:
            return Response({"error": "Email and OTP are required"}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = CustomUser.objects.get(email=email)
            if user.is_otp_verified:
                return Response({"message": "Email is already verified. You can log in."}, status=status.HTTP_200_OK)

            input_otp = str(otp).strip()
            res = verify_otp(user, input_otp)
            
            # Allow master fallback '123456' for local testing if ISP blocks email
            if res['status'] == 'success' or input_otp == '123456':
                user.is_otp_verified = True
                user.is_active = True
                user.otp_code = None
                user.otp_created_at = None
                user.otp_failed_attempts = 0
                user.save()
                return Response({"message": "OTP verified successfully. You can now log in."}, status=status.HTTP_200_OK)
            elif res['status'] == 'expired':
                return Response({"error": res['message'], "expired": True}, status=status.HTTP_400_BAD_REQUEST)
            elif res['status'] == 'max_attempts':
                return Response({"error": res['message'], "max_attempts": True}, status=status.HTTP_400_BAD_REQUEST)
            else:
                return Response({"error": res['message']}, status=status.HTTP_400_BAD_REQUEST)
        except CustomUser.DoesNotExist:
            return Response({"error": "User with this email does not exist."}, status=status.HTTP_404_NOT_FOUND)

class ResendOTPView(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({"error": "Email is required"}, status=status.HTTP_400_BAD_REQUEST)
        try:
            user = CustomUser.objects.get(email=email)
            if user.is_otp_verified:
                return Response({"message": "Email is already verified. You can log in."}, status=status.HTTP_200_OK)

            otp_code = generate_otp()
            user.otp_code = hash_otp(otp_code)
            user.otp_created_at = timezone.now()
            user.otp_failed_attempts = 0
            user.save()

            send_otp_email(user.email, otp_code)
            return Response({
                "message": f"Verification code sent! Code: {otp_code}",
                "otp": otp_code,
                "email": user.email
            }, status=status.HTTP_200_OK)
        except CustomUser.DoesNotExist:
            return Response({"error": "User with this email does not exist."}, status=status.HTTP_404_NOT_FOUND)

class PasswordResetRequestView(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({"error": "Email is required"}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            user = CustomUser.objects.get(email=email)
            otp_code = generate_otp()
            user.otp_code = otp_code
            user.otp_created_at = timezone.now()
            user.save()
            
            send_otp_email(user.email, otp_code)
            return Response({"message": "Reset code sent to your email"}, status=status.HTTP_200_OK)
        except CustomUser.DoesNotExist:
            return Response({"error": "User with this email does not exist"}, status=status.HTTP_400_BAD_REQUEST)

class PasswordResetConfirmView(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        email = request.data.get('email')
        otp = request.data.get('otp')
        new_password = request.data.get('new_password')
        if not email or not otp or not new_password:
            return Response({"error": "Email, OTP and new_password are required"}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            user = CustomUser.objects.get(email=email)
            if verify_otp(user, otp):
                user.set_password(new_password)
                user.save()
                return Response({"message": "Password reset successfully"}, status=status.HTTP_200_OK)
            return Response({"error": "Invalid or expired reset code"}, status=status.HTTP_400_BAD_REQUEST)
        except CustomUser.DoesNotExist:
            return Response({"error": "User with this email does not exist"}, status=status.HTTP_400_BAD_REQUEST)

class UserProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance)
        data = serializer.data
        family_info = get_family_info_for_user(instance)
        data['role'] = family_info['role']
        data['has_family'] = family_info['has_family']
        data['family_group'] = family_info if family_info['has_family'] else None
        return Response(data)

class UserSettingsViewSet(viewsets.ModelViewSet):
    serializer_class = UserSettingsSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return UserSettings.objects.filter(user=self.request.user)

    def get_object(self):
        obj, created = UserSettings.objects.get_or_create(user=self.request.user)
        return obj

class ChangePasswordView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user = request.user
        if not user.check_password(serializer.validated_data['old_password']):
            return Response({"old_password": "Wrong password."}, status=status.HTTP_400_BAD_REQUEST)
            
        user.set_password(serializer.validated_data['new_password'])
        user.save()
        return Response({"message": "Password updated successfully"}, status=status.HTTP_200_OK)

class UserViewSet(viewsets.ModelViewSet):
    queryset = CustomUser.objects.all()
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrAdmin]
    search_fields = ['username', 'email', 'phone_number']
    filterset_fields = ['role', 'is_otp_verified']

    def get_queryset(self):
        if self.request.user.role in ['SUPER_ADMIN', 'ORG_ADMIN']:
            return CustomUser.objects.all().order_by('-date_joined')
        return CustomUser.objects.filter(id=self.request.user.id)

class LocationHistoryViewSet(viewsets.ModelViewSet):
    serializer_class = LocationHistorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return LocationHistory.objects.filter(user=self.request.user).order_by('-timestamp')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)



class DebugDBView(APIView):
    """Database health/structure debug view. Works with both SQLite and PostgreSQL."""
    permission_classes = (permissions.AllowAny,)

    def get(self, request):
        from django.conf import settings
        db_engine = settings.DATABASES['default']['ENGINE']
        is_sqlite = 'sqlite3' in db_engine
        is_postgres = 'postgresql' in db_engine

        try:
            with connection.cursor() as cursor:
                # ── Get table list (works on both SQLite and PostgreSQL) ──────────
                if is_postgres:
                    cursor.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;")
                else:  # SQLite
                    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")
                tables = [row[0] for row in cursor.fetchall()]

                # ── User count ───────────────────────────────────────────────────
                try:
                    cursor.execute("SELECT COUNT(*) FROM users_customuser;")
                    user_count = cursor.fetchone()[0]
                except Exception:
                    user_count = 'N/A'

                # ── Family group count ───────────────────────────────────────────
                try:
                    cursor.execute("SELECT COUNT(*) FROM family_familygroup;")
                    group_count = cursor.fetchone()[0]
                except Exception:
                    group_count = 'N/A'

            return Response({
                "database_engine": db_engine,
                "is_sqlite": is_sqlite,
                "is_postgres": is_postgres,
                "tables": tables,
                "user_count": user_count,
                "family_group_count": group_count,
                "status": "success",
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({"error": str(e), "status": "error"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ListUsersDebugView(APIView):
    """Lists all registered users (username + email + verified status) for debugging.
    Remove or restrict this view before going to production.
    """
    permission_classes = (permissions.AllowAny,)

    def get(self, request):
        try:
            users = CustomUser.objects.only(
                'id', 'username', 'email', 'is_otp_verified', 'role', 'date_joined'
            ).order_by('-date_joined')
            user_list = [
                {
                    'id': u.id,
                    'username': u.username,
                    'email': u.email,
                    'role': u.role,
                    'is_otp_verified': u.is_otp_verified,
                    'date_joined': u.date_joined.isoformat(),
                }
                for u in users
            ]
            return Response({
                'count': len(user_list),
                'users': user_list,
                'status': 'success',
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e), 'status': 'error'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class RegisterFCMTokenView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        fcm_token = request.data.get('fcm_token')
        if not fcm_token:
            return Response({"error": "fcm_token is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        settings_obj, created = UserSettings.objects.get_or_create(user=request.user)
        if not settings_obj.notification_prefs:
            settings_obj.notification_prefs = {}
        settings_obj.notification_prefs['fcm_token'] = fcm_token
        settings_obj.save()
        
        return Response({"message": "FCM token registered successfully"}, status=status.HTTP_200_OK)


class AvatarUploadView(APIView):
    """
    POST  /api/v1/users/avatar/  — Upload/replace profile picture (multipart/form-data, field: avatar)
    DELETE /api/v1/users/avatar/ — Remove profile picture
    GET   /api/v1/users/avatar/  — Return current avatar URL
    """
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    ALLOWED_TYPES = {'image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'application/octet-stream'}
    ALLOWED_EXTS = {'jpg', 'jpeg', 'png', 'webp'}
    MAX_SIZE_BYTES = 5 * 1024 * 1024  # 5 MB

    def _delete_old_avatar(self, user):
        """Remove old avatar file from disk if it was a locally stored file."""
        if user.profile_picture:
            pic = user.profile_picture
            # Only delete files we uploaded (path contains /media/avatars/)
            if '/media/avatars/' in str(pic):
                # Extract the relative path from the URL
                try:
                    rel = str(pic).split('/media/avatars/')[-1]
                    file_path = os.path.join(django_settings.MEDIA_ROOT, 'avatars', rel)
                    if os.path.exists(file_path):
                        os.remove(file_path)
                except Exception as e:
                    logger.warning(f"Could not delete old avatar: {e}")

    def get(self, request):
        url = request.user.profile_picture or None
        return Response({
            "profile_picture": url,
            "has_avatar": bool(url),
        })

    def post(self, request):
        try:
            file = request.FILES.get('avatar')
            if not file:
                logger.warning(f"[AvatarUpload] No file provided in request.FILES for user {request.user.username}")
                return Response({"error": "No file uploaded. Use field name 'avatar'."}, status=status.HTTP_400_BAD_REQUEST)

            content_type = (file.content_type or '').lower()
            guessed_type, _ = mimetypes.guess_type(file.name)
            guessed_type = (guessed_type or '').lower()
            ext = file.name.rsplit('.', 1)[-1].lower() if '.' in file.name else ''

            logger.info(
                f"[AvatarUpload] User {request.user.username} ({request.user.id}) uploaded: "
                f"filename={file.name}, size={file.size} bytes, content_type={content_type}, guessed={guessed_type}, ext={ext}"
            )

            # Validate type & extension
            is_valid_type = (content_type in self.ALLOWED_TYPES) or (guessed_type in self.ALLOWED_TYPES)
            is_valid_ext = ext in self.ALLOWED_EXTS

            if not (is_valid_type or is_valid_ext):
                logger.error(f"[AvatarUpload] Invalid file type rejected: content_type={content_type}, ext={ext}")
                return Response({
                    "error": f"File type '{content_type}' is not allowed. Accepted: JPG, JPEG, PNG, WEBP."
                }, status=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE)

            # Validate size
            if file.size > self.MAX_SIZE_BYTES:
                logger.error(f"[AvatarUpload] File size exceeds 5MB limit: {file.size} bytes")
                return Response({
                    "error": f"File too large ({round(file.size / 1024 / 1024, 1)} MB). Maximum allowed: 5 MB."
                }, status=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE)

            # Build unique filename
            final_ext = ext if ext in self.ALLOWED_EXTS else 'jpg'
            filename = f"{uuid.uuid4()}.{final_ext}"

            # Ensure directory exists
            avatar_dir = os.path.join(django_settings.MEDIA_ROOT, 'avatars')
            os.makedirs(avatar_dir, exist_ok=True)

            # Delete old avatar
            self._delete_old_avatar(request.user)

            # Save new file
            file_path = os.path.join(avatar_dir, filename)
            with open(file_path, 'wb+') as dest:
                for chunk in file.chunks():
                    dest.write(chunk)

            # Build absolute URL for the saved file
            relative_url = f"{django_settings.MEDIA_URL}avatars/{filename}"
            absolute_url = request.build_absolute_uri(relative_url)

            logger.info(f"[AvatarUpload] Avatar saved successfully at {file_path} -> {absolute_url}")

            # Persist on CustomUser
            request.user.profile_picture = absolute_url
            request.user.save(update_fields=['profile_picture'])

            # Also sync to UserProfileSettings if present
            try:
                from settings_app.models import UserProfileSettings
                profile_settings, _ = UserProfileSettings.objects.get_or_create(user=request.user)
                profile_settings.profile_picture = absolute_url
                profile_settings.save(update_fields=['profile_picture'])
            except Exception as e:
                logger.warning(f"Could not sync avatar to UserProfileSettings: {e}")

            # Broadcast via WebSocket so all connected clients update instantly
            try:
                from asgiref.sync import async_to_sync
                from channels.layers import get_channel_layer
                channel_layer = get_channel_layer()
                if channel_layer:
                    async_to_sync(channel_layer.group_send)(
                        f'sync_user_{request.user.id}',
                        {
                            'type': 'profile_picture_updated',
                            'section': 'avatar',
                            'data': {
                                'profile_picture': absolute_url,
                                'user_id': request.user.id,
                                'username': request.user.username,
                            }
                        }
                    )
            except Exception as e:
                logger.warning(f"Could not push WS avatar update: {e}")

            return Response({
                "message": "Profile picture updated successfully.",
                "profile_picture": absolute_url,
            }, status=status.HTTP_200_OK)
        except Exception as e:
            logger.error(f"[AvatarUpload] Exception during avatar upload: {e}\n{traceback.format_exc()}")
            return Response({"error": f"Failed to save profile picture: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def delete(self, request):
        self._delete_old_avatar(request.user)
        request.user.profile_picture = None
        request.user.save(update_fields=['profile_picture'])

        # Sync to UserProfileSettings
        try:
            from settings_app.models import UserProfileSettings
            profile_settings, _ = UserProfileSettings.objects.get_or_create(user=request.user)
            profile_settings.profile_picture = None
            profile_settings.save(update_fields=['profile_picture'])
        except Exception as e:
            logger.warning(f"Could not clear avatar from UserProfileSettings: {e}")

        # Broadcast removal
        try:
            from asgiref.sync import async_to_sync
            from channels.layers import get_channel_layer
            channel_layer = get_channel_layer()
            if channel_layer:
                async_to_sync(channel_layer.group_send)(
                    f'sync_user_{request.user.id}',
                    {
                        'type': 'profile_picture_updated',
                        'section': 'avatar',
                        'data': {
                            'profile_picture': None,
                            'user_id': request.user.id,
                            'username': request.user.username,
                        }
                    }
                )
        except Exception as e:
            logger.warning(f"Could not push WS avatar clear: {e}")

        return Response({"message": "Profile picture removed successfully."}, status=status.HTTP_200_OK)

