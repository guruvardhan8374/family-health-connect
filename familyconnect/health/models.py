from django.db import models
from django.conf import settings
from django.utils import timezone


class HealthSnapshot(models.Model):
    """
    One snapshot = one sync batch from mobile / manual entry.
    Stores all vitals together so we can chart trends per timestamp.
    """
    SOURCE_CHOICES = (
        ('MANUAL', 'Manual Entry'),
        ('HEALTH_CONNECT', 'Android Health Connect'),
        ('WEARABLE', 'Wearable Device'),
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='health_snapshots'
    )
    recorded_at = models.DateTimeField(default=timezone.now, db_index=True)
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default='MANUAL')

    # Vitals
    heart_rate      = models.FloatField(null=True, blank=True, help_text='bpm')
    steps           = models.IntegerField(null=True, blank=True, help_text='step count')
    calories        = models.FloatField(null=True, blank=True, help_text='kcal burned')
    distance        = models.FloatField(null=True, blank=True, help_text='km')
    sleep_hours     = models.FloatField(null=True, blank=True, help_text='hours of sleep')
    spo2            = models.FloatField(null=True, blank=True, help_text='blood oxygen %')
    hydration       = models.FloatField(null=True, blank=True, help_text='litres of water')
    weight          = models.FloatField(null=True, blank=True, help_text='kg')
    height          = models.FloatField(null=True, blank=True, help_text='cm')
    blood_pressure  = models.CharField(max_length=20, null=True, blank=True, help_text='e.g. 120/80')
    notes           = models.TextField(blank=True, default='')

    class Meta:
        ordering = ['-recorded_at']
        indexes = [
            models.Index(fields=['user', 'recorded_at']),
        ]

    def __str__(self):
        return f"{self.user.username} snapshot @ {self.recorded_at:%Y-%m-%d %H:%M}"

    @property
    def bmi(self):
        """Calculated BMI from weight and height in this snapshot."""
        if self.weight and self.height and self.height > 0:
            h_m = self.height / 100
            return round(self.weight / (h_m * h_m), 1)
        return None


class HealthGoal(models.Model):
    """Daily targets per user. One active row per user."""
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='health_goal'
    )
    steps_goal      = models.IntegerField(default=10000)
    calories_goal   = models.FloatField(default=2000)
    hydration_goal  = models.FloatField(default=2.0)   # litres
    sleep_goal      = models.FloatField(default=8.0)   # hours
    distance_goal   = models.FloatField(default=5.0)   # km
    updated_at      = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.username} goals"


class HealthMetric(models.Model):
    """Legacy single-value metric — kept for backwards compatibility."""
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
    """Auto-generated alert when vitals cross a threshold."""
    ALERT_TYPES = (
        ('HIGH_HR', 'High Heart Rate'),
        ('LOW_HR', 'Low Heart Rate'),
        ('LOW_SPO2', 'Low Blood Oxygen'),
        ('INACTIVITY', 'Extended Inactivity'),
        ('GENERAL', 'General Alert'),
    )
    SEVERITY = (
        ('INFO', 'Info'),
        ('WARNING', 'Warning'),
        ('CRITICAL', 'Critical'),
    )

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='health_alerts')
    alert_type = models.CharField(max_length=20, choices=ALERT_TYPES, default='GENERAL')
    severity = models.CharField(max_length=10, choices=SEVERITY, default='WARNING')
    title = models.CharField(max_length=100)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    snapshot = models.ForeignKey(HealthSnapshot, null=True, blank=True, on_delete=models.SET_NULL)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.severity}] {self.user.username}: {self.title}"
