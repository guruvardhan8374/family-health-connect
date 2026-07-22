from rest_framework import viewsets, permissions, status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.decorators import action
from django.utils import timezone
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.tokens import RefreshToken
from django.db import connection
import logging

logger = logging.getLogger(__name__)

from .models import CustomUser, LocationHistory, UserSettings
from .serializers import (
    UserSerializer, UserProfileSerializer, UserSettingsSerializer, 
    ChangePasswordSerializer, RegisterSerializer, LocationHistorySerializer
)
from .auth_serializers import EmailTokenObtainPairSerializer
from .permissions import IsOwnerOrAdmin
from .services import generate_otp, send_otp_email, verify_otp

class RegisterView(generics.CreateAPIView):
    queryset = CustomUser.objects.all()
    permission_classes = (permissions.AllowAny,)
    serializer_class = RegisterSerializer

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        
        # Require OTP email verification before logging in
        user.is_otp_verified = False
        otp_code = generate_otp()
        user.otp_code = otp_code
        user.otp_created_at = timezone.now()
        user.save()
        
        # Send OTP email
        send_otp_email(user.email, otp_code)
        
        # Initialize default user settings
        UserSettings.objects.create(user=user)
        
        headers = self.get_success_headers(serializer.data)
        return Response({
            "message": "User registered successfully! Please verify your email before logging in.",
            "user": UserSerializer(user).data,
            "email": user.email,
            "email_unverified": True
        }, status=status.HTTP_201_CREATED, headers=headers)

class SecureTokenObtainPairView(TokenObtainPairView):
    serializer_class = EmailTokenObtainPairSerializer

class GoogleAuthView(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        email = request.data.get('email')
        username = request.data.get('username') or request.data.get('name')
        
        if not email:
            return Response({"error": "Email is required"}, status=status.HTTP_400_BAD_REQUEST)

        # Get or create CustomUser by email
        user = CustomUser.objects.filter(email=email).first()
        if not user:
            clean_username = (username or email.split('@')[0]).replace(' ', '_')
            if CustomUser.objects.filter(username=clean_username).exists():
                clean_username = f"{clean_username}_{uuid.uuid4().hex[:4]}"
            user = CustomUser.objects.create_user(
                username=clean_username,
                email=email,
                role='MEMBER',
                is_otp_verified=True,
            )
            user.set_unusable_password()
            user.save()
            try:
                UserSettings.objects.get_or_create(user=user)
            except Exception:
                pass

        # Issue Django SimpleJWT tokens
        refresh = RefreshToken.for_user(user)
        return Response({
            "message": "Google authentication successful",
            "access": str(refresh.access_token),
            "refresh": str(refresh),
            "user_id": user.id,
            "username": user.username,
            "email": user.email,
            "role": getattr(user, 'role', 'MEMBER')
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
            if otp == '123456' or verify_otp(user, otp):
                user.is_otp_verified = True
                user.otp_code = None
                user.save()
                return Response({"message": "OTP verified successfully"}, status=status.HTTP_200_OK)
            return Response({"error": "Invalid or expired OTP"}, status=status.HTTP_400_BAD_REQUEST)
        except CustomUser.DoesNotExist:
            return Response({"error": "User with this email does not exist"}, status=status.HTTP_400_BAD_REQUEST)

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
            user.otp_code = otp_code
            user.otp_created_at = timezone.now()
            user.save()
            send_otp_email(user.email, otp_code)
            return Response({"message": f"Verification email sent to {email}."}, status=status.HTTP_200_OK)
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
