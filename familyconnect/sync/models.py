from django.db import models
from django.conf import settings


class AIAssistantHistory(models.Model):
    """Persists AI Assistant chat turns so they sync across web and mobile."""
    ROLE_CHOICES = (
        ('user', 'User'),
        ('assistant', 'Assistant'),
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='ai_history',
    )
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='user')
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"[{self.role}] {self.user.username}: {self.content[:50]}"


class PendingSyncLog(models.Model):
    """Audit log for offline mutations replayed from a client queue."""
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('applied', 'Applied'),
        ('failed', 'Failed'),
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='pending_sync_logs',
    )
    endpoint = models.CharField(max_length=255)
    method = models.CharField(max_length=10, default='POST')
    payload = models.JSONField(default=dict)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    error_message = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    applied_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"[{self.status}] {self.method} {self.endpoint} by {self.user.username}"
