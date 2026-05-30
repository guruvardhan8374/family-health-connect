from django.contrib.auth.models import AbstractUser
from django.db import models

class CustomUser(AbstractUser):
    ROLE_CHOICES = (
        ('SUPER_ADMIN', 'Super Admin'),
        ('ORG_ADMIN', 'Organization Admin'),
        ('HEAD', 'Family Head'),
        ('MEMBER', 'Family Member'),
    )
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    profile_picture = models.URLField(blank=True, null=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='MEMBER')
    otp_code = models.CharField(max_length=6, blank=True, null=True)
    otp_created_at = models.DateTimeField(blank=True, null=True)
    is_otp_verified = models.BooleanField(default=False)
    
    # New profile fields
    date_of_birth = models.DateField(blank=True, null=True)
    gender = models.CharField(max_length=20, blank=True, null=True)
    blood_group = models.CharField(max_length=10, blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    emergency_phone = models.CharField(max_length=20, blank=True, null=True)

    def __str__(self):
        return f"{self.username} ({self.get_role_display()})"

class LocationHistory(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='location_history')
    latitude = models.FloatField()
    longitude = models.FloatField()
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} at {self.latitude}, {self.longitude}"

class UserSettings(models.Model):
    user = models.OneToOneField(CustomUser, on_delete=models.CASCADE, related_name='settings')
    theme_mode = models.CharField(max_length=10, default='light')
    language = models.CharField(max_length=10, default='en')
    notification_prefs = models.JSONField(default=dict, blank=True)
    privacy_settings = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Settings for {self.user.username}"

# Keep for backward compatibility/migrations helper until notifications app is fully up
class Notification(models.Model):
    NOTIFICATION_TYPES = (
        ('HEALTH', 'Health Alert'),
        ('REMINDER', 'Reminder'),
        ('EMERGENCY', 'Emergency'),
        ('SYSTEM', 'System'),
    )
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='legacy_notifications')
    type = models.CharField(max_length=20, choices=NOTIFICATION_TYPES, default='SYSTEM')
    title = models.CharField(max_length=100)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"[Legacy] {self.title} for {self.user.username}"

