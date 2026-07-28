from rest_framework import serializers
from .models import (
    UserProfileSettings, NotificationSettings,
    PrivacySettings, ThemeSettings, AccountSettings
)


class UserProfileSettingsSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', required=False, allow_blank=True)
    email = serializers.EmailField(source='user.email', read_only=True)
    date_of_birth = serializers.DateField(required=False, allow_null=True, input_formats=['%Y-%m-%d', '%Y/%m/%d', '%d-%m-%Y', '%d/%m/%Y', 'iso-8601'])
    profile_picture = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    phone_number = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    bio = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    emergency_contact = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    emergency_phone = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    gender = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    blood_group = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    address = serializers.CharField(required=False, allow_null=True, allow_blank=True)

    class Meta:
        model = UserProfileSettings
        fields = [
            'username', 'email', 'profile_picture', 'phone_number', 'bio',
            'emergency_contact', 'emergency_phone', 'preferred_language',
            'timezone', 'date_of_birth', 'gender', 'blood_group', 'address',
            'updated_at'
        ]
        read_only_fields = ['updated_at']

    def to_internal_value(self, data):
        mutable_data = data.copy() if hasattr(data, 'copy') else dict(data)
        optional_fields = ['date_of_birth', 'profile_picture', 'phone_number', 'bio', 'emergency_contact', 'emergency_phone', 'gender', 'blood_group', 'address']
        for field in optional_fields:
            if field in mutable_data:
                val = mutable_data[field]
                if val == '' or val is None or val == 'null':
                    mutable_data[field] = None if field == 'date_of_birth' else ''
        return super().to_internal_value(mutable_data)

    def update(self, instance, validated_data):
        user_data = validated_data.pop('user', {})
        username = user_data.get('username') or validated_data.pop('username', None)
        if username and username != instance.user.username:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            if User.objects.filter(username=username).exclude(id=instance.user.id).exists():
                raise serializers.ValidationError({"username": "This username is already taken."})
            instance.user.username = username
            instance.user.save()

        # Update remaining fields on settings instance and CustomUser
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
            if hasattr(instance.user, attr):
                setattr(instance.user, attr, value)

        instance.user.save()
        instance.save()
        return instance


class NotificationSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationSettings
        fields = [
            'push_notifications', 'medicine_reminders', 'health_reminders',
            'emergency_alerts', 'family_notifications', 'chat_notifications',
            'email_notifications', 'updated_at'
        ]
        read_only_fields = ['updated_at']


class PrivacySettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = PrivacySettings
        fields = [
            'profile_visibility', 'health_data_visibility', 'family_visibility',
            'location_sharing', 'emergency_visibility', 'updated_at',
            'share_heart_rate', 'share_steps', 'share_calories',
            'share_sleep', 'share_spo2', 'share_weight', 'share_blood_pressure',
        ]
        read_only_fields = ['updated_at']


class ThemeSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = ThemeSettings
        fields = ['dark_mode', 'theme_color', 'updated_at']
        read_only_fields = ['updated_at']


class AccountSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = AccountSettings
        fields = [
            'two_factor_auth_enabled', 'delete_account_enabled',
            'change_password_enabled', 'account_deletion_requested', 'updated_at'
        ]
        read_only_fields = ['updated_at']
