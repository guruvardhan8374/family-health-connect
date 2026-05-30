from django.db import models
from django.conf import settings
from django.utils import timezone

class HealthRecord(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='health_records'
    )
    recorded_date = models.DateField(default=timezone.now)
    heart_rate = models.IntegerField(default=0)
    oxygen_level = models.IntegerField(default=0) # oxygen level in % (e.g. 98)
    blood_pressure = models.CharField(max_length=20, default="120/80")
    sleep_hours = models.FloatField(default=0.0)
    water_intake = models.FloatField(default=0.0) # in liters
    calories_burned = models.IntegerField(default=0)
    steps = models.IntegerField(default=0)
    weight = models.FloatField(default=0.0) # in kg
    height = models.FloatField(default=0.0) # in cm
    bmi = models.FloatField(default=0.0)
    stress_level = models.IntegerField(default=0) # 0 to 10 scale
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.recorded_date}"