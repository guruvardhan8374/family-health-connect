from django.db import models
from django.conf import settings


class UserProfileSettings(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='profile_settings'
    )
    profile_picture = models.TextField(blank=True, null=True)
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    bio = models.TextField(blank=True, null=True)
    emergency_contact = models.CharField(max_length=100, blank=True, null=True)
    emergency_phone = models.CharField(max_length=20, blank=True, null=True)
    preferred_language = models.CharField(max_length=10, default='en')
    timezone = models.CharField(max_length=50, default='UTC')
    date_of_birth = models.DateField(blank=True, null=True)
    gender = models.CharField(max_length=20, blank=True, null=True)
    blood_group = models.CharField(max_length=10, blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Profile settings for {self.user.username}"


class NotificationSettings(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notification_settings'
    )
    push_notifications = models.BooleanField(default=True)
    medicine_reminders = models.BooleanField(default=True)
    health_reminders = models.BooleanField(default=True)
    emergency_alerts = models.BooleanField(default=True)
    family_notifications = models.BooleanField(default=True)
    chat_notifications = models.BooleanField(default=True)
    email_notifications = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Notification settings for {self.user.username}"


class PrivacySettings(models.Model):
    VISIBILITY_CHOICES = (
        ('PUBLIC', 'Public'),
        ('FAMILY', 'Family Only'),
        ('PRIVATE', 'Private'),
    )
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='privacy_settings'
    )
    profile_visibility = models.CharField(
        max_length=10, choices=VISIBILITY_CHOICES, default='FAMILY'
    )
    health_data_visibility = models.CharField(
        max_length=10, choices=VISIBILITY_CHOICES, default='FAMILY'
    )
    family_visibility = models.CharField(
        max_length=10, choices=VISIBILITY_CHOICES, default='FAMILY'
    )
    location_sharing = models.BooleanField(default=True)
    emergency_visibility = models.CharField(
        max_length=10, choices=VISIBILITY_CHOICES, default='FAMILY'
    )

    # Granular health metrics visibility settings
    share_heart_rate      = models.BooleanField(default=True)
    share_steps           = models.BooleanField(default=True)
    share_calories        = models.BooleanField(default=True)
    share_sleep           = models.BooleanField(default=True)
    share_spo2            = models.BooleanField(default=True)
    share_weight          = models.BooleanField(default=True)
    share_blood_pressure  = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Privacy settings for {self.user.username}"


class ThemeSettings(models.Model):
    THEME_COLOR_CHOICES = (
        ('blue', 'Blue'),
        ('emerald', 'Emerald'),
        ('indigo', 'Indigo'),
        ('rose', 'Rose'),
        ('violet', 'Violet'),
        ('orange', 'Orange'),
    )
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='theme_settings'
    )
    dark_mode = models.BooleanField(default=False)
    theme_color = models.CharField(
        max_length=20, choices=THEME_COLOR_CHOICES, default='blue'
    )
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Theme settings for {self.user.username}"


class AccountSettings(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='account_settings'
    )
    two_factor_auth_enabled = models.BooleanField(default=False)
    delete_account_enabled = models.BooleanField(default=True)
    change_password_enabled = models.BooleanField(default=True)
    account_deletion_requested = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Account settings for {self.user.username}"
