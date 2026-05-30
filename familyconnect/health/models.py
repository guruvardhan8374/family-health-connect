from django.db import models
from django.conf import settings

class HealthMetric(models.Model):
    METRIC_TYPES = (
        ('HEART_RATE', 'Heart Rate'),
        ('STEPS', 'Steps'),
        ('SLEEP', 'Sleep Score'),
        ('HYDRATION', 'Hydration (L)'),
        ('CALORIES', 'Calories Burned'),
        ('OXYGEN', 'Oxygen Level (%)'),
        ('STRESS', 'Stress Level'),
        ('BLOOD_PRESSURE', 'Blood Pressure'),
    )
    
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='health_metrics')
    metric_type = models.CharField(max_length=20, choices=METRIC_TYPES)
    value = models.FloatField()
    unit = models.CharField(max_length=20, blank=True, null=True)
    recorded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.get_metric_type_display()}: {self.value}"

class HealthAlert(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='health_alerts')
    title = models.CharField(max_length=100)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Alert for {self.user.username}: {self.title}"
