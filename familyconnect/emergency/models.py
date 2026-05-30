from django.db import models
from django.conf import settings

class EmergencyContact(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='emergency_contacts')
    name = models.CharField(max_length=100)
    relation = models.CharField(max_length=50)
    phone_number = models.CharField(max_length=20)

    def __str__(self):
        return f"{self.name} ({self.relation}) for {self.user.username}"

class SOSAlert(models.Model):
    STATUS_CHOICES = (
        ('ACTIVE', 'Active'),
        ('RESOLVED', 'Resolved'),
        ('FALSE_ALARM', 'False Alarm'),
    )
    
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='sos_alerts')
    location_lat = models.FloatField(null=True, blank=True)
    location_lng = models.FloatField(null=True, blank=True)
    message = models.TextField(blank=True, null=True, default="Emergency! I need help immediately.")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACTIVE')
    is_resolved = models.BooleanField(default=False)
    triggered_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    vitals_snapshot = models.JSONField(default=dict, blank=True) # Snapshot of HR, O2, etc. at time of SOS

    def __str__(self):
        return f"SOS by {self.user.username} at {self.triggered_at} - Status: {self.status}"

class NearbyHospital(models.Model):
    name = models.CharField(max_length=150)
    address = models.TextField()
    phone_number = models.CharField(max_length=20)
    latitude = models.FloatField()
    longitude = models.FloatField()
    distance_km = models.FloatField(default=0.0)

    def __str__(self):
        return f"{self.name} ({self.distance_km} km)"
