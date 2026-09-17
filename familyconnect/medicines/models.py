from django.db import models
from django.conf import settings
from django.utils import timezone


class Medicine(models.Model):
    FREQUENCY_CHOICES = (
        ('ONCE_DAILY', 'Once Daily'),
        ('TWICE_DAILY', 'Twice Daily'),
        ('THREE_TIMES_DAILY', 'Three Times Daily'),
        ('CUSTOM', 'Custom'),
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='medicines'
    )
    name = models.CharField(max_length=150)
    dosage = models.CharField(max_length=50, help_text="Amount, e.g. '500' or '1'")
    dosage_unit = models.CharField(max_length=50, default='Tablet', help_text="e.g. Tablet, Capsule, mL, Drops")
    frequency = models.CharField(max_length=50, choices=FREQUENCY_CHOICES, default='ONCE_DAILY')
    reminder_times = models.JSONField(default=list, help_text="List of HH:MM strings, e.g. ['08:00', '20:00']")
    start_date = models.DateField(default=timezone.now)
    end_date = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True, default='', help_text="Instructions, e.g. 'Take after food'")
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.name} ({self.dosage} {self.dosage_unit}) - {self.user.username}"


class MedicineDoseLog(models.Model):
    STATUS_CHOICES = (
        ('TAKEN', 'Taken'),
        ('MISSED', 'Missed'),
    )

    medicine = models.ForeignKey(
        Medicine,
        on_delete=models.CASCADE,
        related_name='dose_logs'
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='medicine_dose_logs'
    )
    scheduled_date = models.DateField(default=timezone.now)
    dose_time = models.CharField(max_length=10, help_text="HH:MM formatted dose time")
    taken_at = models.DateTimeField(default=timezone.now)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='TAKEN')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-taken_at']
        constraints = [
            models.UniqueConstraint(
                fields=['medicine', 'scheduled_date', 'dose_time'],
                name='unique_medicine_scheduled_dose_log'
            )
        ]

    def __str__(self):
        return f"{self.medicine.name} at {self.dose_time} on {self.scheduled_date} ({self.status})"
