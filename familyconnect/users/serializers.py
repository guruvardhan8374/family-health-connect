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
    bio = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    emergency_contact = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    date_of_birth = serializers.DateField(required=False, allow_null=True, input_formats=['%Y-%m-%d', '%Y/%m/%d', '%d-%m-%Y', '%d/%m/%Y', 'iso-8601'])

    class Meta:
        model = CustomUser
        fields = [
            'id', 'username', 'email', 'first_name', 'last_name', 'phone_number', 
            'profile_picture', 'role', 'is_otp_verified', 'date_of_birth', 'gender', 
            'blood_group', 'address', 'bio', 'emergency_contact', 'emergency_phone'
        ]
        read_only_fields = ['id', 'email', 'role', 'is_otp_verified']

    def update(self, instance, validated_data):
        username = validated_data.pop('username', None)
        if username and username != instance.username:
            if CustomUser.objects.filter(username=username).exclude(id=instance.id).exists():
                raise serializers.ValidationError({"username": "This username is already taken."})
            instance.username = username

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        # Keep UserProfileSettings in full sync
        try:
            from settings_app.models import UserProfileSettings
            profile_settings, _ = UserProfileSettings.objects.get_or_create(user=instance)
            for attr in ['profile_picture', 'phone_number', 'bio', 'emergency_contact', 'emergency_phone', 'date_of_birth', 'gender', 'blood_group', 'address']:
                if hasattr(instance, attr):
                    setattr(profile_settings, attr, getattr(instance, attr))
            profile_settings.save()
        except Exception as e:
            pass

        return instance

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
        fields = ['username', 'email', 'password', 'password_confirm', 'role']

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
            role=validated_data.get('role', 'MEMBER')
        )
        return user

class LocationHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = LocationHistory
        fields = ['id', 'user', 'latitude', 'longitude', 'speed', 'battery_level', 'is_moving', 'timestamp']
        read_only_fields = ['id', 'timestamp', 'user']
