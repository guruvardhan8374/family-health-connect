from rest_framework import viewsets, permissions, status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.decorators import action
from django.utils import timezone
from django_ratelimit.decorators import ratelimit
from rest_framework_simplejwt.views import TokenObtainPairView
from django.utils.decorators import method_decorator

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

    @method_decorator(ratelimit(key='ip', rate='5/m', method='POST', block=True))
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        
        # Generate OTP code
        otp_code = generate_otp()
        user.otp_code = otp_code
        user.otp_created_at = timezone.now()
        user.save()
        
        # Send OTP
        send_otp_email(user.email, otp_code)
        
        # Initialize default user settings
        UserSettings.objects.create(user=user)
        
        headers = self.get_success_headers(serializer.data)
        return Response({
            "message": "User registered successfully. Please verify using the OTP sent to your email.",
            "user": UserSerializer(user).data
        }, status=status.HTTP_201_CREATED, headers=headers)

class SecureTokenObtainPairView(TokenObtainPairView):
    serializer_class = EmailTokenObtainPairSerializer

class VerifyOTPView(APIView):
    permission_classes = (permissions.AllowAny,)

    @method_decorator(ratelimit(key='ip', rate='10/m', method='POST', block=True))
    def post(self, request):
        email = request.data.get('email')
        otp = request.data.get('otp')
        if not email or not otp:
            return Response({"error": "Email and OTP are required"}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = CustomUser.objects.get(email=email)
            if verify_otp(user, otp):
                return Response({"message": "OTP verified successfully"}, status=status.HTTP_200_OK)
            return Response({"error": "Invalid or expired OTP"}, status=status.HTTP_400_BAD_REQUEST)
        except CustomUser.DoesNotExist:
            return Response({"error": "User with this email does not exist"}, status=status.HTTP_400_BAD_REQUEST)

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
