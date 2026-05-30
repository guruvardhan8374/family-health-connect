from django.db import models
from django.conf import settings

class SyncHistory(models.Model):
    PLATFORM_CHOICES = (
        ('GOOGLE_FIT', 'Google Fit'),
        ('APPLE_HEALTH', 'Apple Health'),
        ('FITBIT', 'Fitbit'),
        ('GARMIN', 'Garmin'),
    )
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='sync_histories')
    platform = models.CharField(max_length=20, choices=PLATFORM_CHOICES)
    last_sync = models.DateTimeField(auto_now=True)
    status = models.CharField(max_length=20, default='SUCCESS')
    data_points_synced = models.IntegerField(default=0)

    def __str__(self):
        return f"{self.user.username} - {self.platform} - {self.last_sync}"
