from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from .models import CustomUser, LocationHistory, UserSettings

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomUser
        fields = [
            'id', 'username', 'email', 'phone_number', 'profile_picture', 'role', 
            'is_otp_verified', 'date_of_birth', 'gender', 'blood_group', 'address', 'emergency_phone'
        ]
        read_only_fields = ['id', 'is_otp_verified', 'role']

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomUser
        fields = [
            'id', 'username', 'email', 'first_name', 'last_name', 'phone_number', 
            'profile_picture', 'role', 'is_otp_verified', 'date_of_birth', 'gender', 
            'blood_group', 'address', 'emergency_phone'
        ]
        read_only_fields = ['id', 'username', 'email', 'role', 'is_otp_verified']

class UserSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserSettings
        fields = ['theme_mode', 'language', 'notification_prefs', 'privacy_settings', 'created_at', 'updated_at']
        read_only_fields = ['created_at', 'updated_at']

class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True, write_only=True)
    new_password = serializers.CharField(required=True, write_only=True, validators=[validate_password])
    confirm_password = serializers.CharField(required=True, write_only=True)

    def validate(self, attrs):
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError({"confirm_password": "New passwords do not match."})
        return attrs

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = CustomUser
        fields = ['username', 'email', 'password', 'password_confirm', 'phone_number', 'role']

    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({"password_confirm": "Passwords do not match."})
        if not attrs.get('email'):
            raise serializers.ValidationError({"email": "Email is required."})
        if CustomUser.objects.filter(email=attrs['email']).exists():
            raise serializers.ValidationError({"email": "A user with this email already exists."})
        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        user = CustomUser.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            phone_number=validated_data.get('phone_number'),
            role=validated_data.get('role', 'MEMBER')
        )
        return user

class LocationHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = LocationHistory
        fields = ['id', 'user', 'latitude', 'longitude', 'timestamp']
        read_only_fields = ['id', 'timestamp']
