from django.db import models
from django.conf import settings

class AuditLog(models.Model):
    ACTION_CHOICES = (
        ('LOGIN', 'User Login'),
        ('LOGOUT', 'User Logout'),
        ('REGISTER', 'User Registration'),
        ('PASSWORD_CHANGE', 'Password Change'),
        ('PROFILE_UPDATE', 'Profile Update'),
        ('FAMILY_JOIN', 'Join Family Group'),
        ('FAMILY_LEAVE', 'Leave Family Group'),
        ('DATA_ACCESS', 'Health Data Access'),
        ('DATA_UPDATE', 'Health Data Update'),
        ('SOS_TRIGGER', 'Emergency SOS Trigger'),
        ('SETTINGS_CHANGE', 'Security Settings Change'),
    )
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    resource = models.CharField(max_length=100, blank=True, null=True)
    ip_address = models.GenericIPAddressField(null=True)
    user_agent = models.TextField(blank=True, null=True)
    timestamp = models.DateTimeField(auto_now_add=True)
    details = models.JSONField(default=dict)

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        return f"{self.user} - {self.action} at {self.timestamp}"
