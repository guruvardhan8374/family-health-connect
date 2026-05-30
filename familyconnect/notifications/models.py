from django.db import models
from django.conf import settings

class Notification(models.Model):
    NOTIFICATION_TYPES = (
        ('HEALTH', 'Health Alert'),
        ('REMINDER', 'Reminder'),
        ('EMERGENCY', 'Emergency SOS'),
        ('SYSTEM', 'System'),
        ('MEDICINE', 'Medicine'),
        ('WATER', 'Water Intake'),
        ('SLEEP', 'Sleep'),
    )
    
    PRIORITY_CHOICES = (
        ('LOW', 'Low'),
        ('NORMAL', 'Normal'),
        ('HIGH', 'High'),
        ('URGENT', 'Urgent'),
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications'
    )
    type = models.CharField(max_length=20, choices=NOTIFICATION_TYPES, default='SYSTEM')
    title = models.CharField(max_length=150)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    data = models.JSONField(default=dict, blank=True)
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='NORMAL')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} for {self.user.username} ({self.priority})"

class Reminder(models.Model):
    REMINDER_TYPES = (
        ('MEDICINE', 'Medicine'),
        ('WATER', 'Water'),
        ('SLEEP', 'Sleep'),
        ('EXERCISE', 'Exercise'),
        ('CUSTOM', 'Custom'),
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='reminders'
    )
    reminder_type = models.CharField(max_length=20, choices=REMINDER_TYPES, default='CUSTOM')
    title = models.CharField(max_length=150)
    message = models.TextField(blank=True, null=True)
    time = models.TimeField() # Time of day when the reminder fires
    repeat_days = models.JSONField(default=list, blank=True) # e.g. ["Monday", "Wednesday"]
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} for {self.user.username} at {self.time}"
