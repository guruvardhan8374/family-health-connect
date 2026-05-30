from django.db import models
from django.conf import settings

class SubscriptionPlan(models.Model):
    PLAN_CHOICES = (
        ('FREE', 'Free / Trial'),
        ('PRO', 'Family Pro'),
        ('ENTERPRISE', 'Organization Enterprise'),
    )
    name = models.CharField(max_length=20, choices=PLAN_CHOICES, unique=True)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    max_members = models.IntegerField(default=5)
    has_ai_analytics = models.BooleanField(default=False)
    has_voice_assistant = models.BooleanField(default=False)
    has_iot_sync = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.get_name_display()

class Subscription(models.Model):
    STATUS_CHOICES = (
        ('ACTIVE', 'Active'),
        ('EXPIRED', 'Expired'),
        ('CANCELLED', 'Cancelled'),
        ('TRIAL', 'Trialing'),
    )
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='subscription')
    plan = models.ForeignKey(SubscriptionPlan, on_delete=models.SET_NULL, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='TRIAL')
    stripe_customer_id = models.CharField(max_length=100, blank=True, null=True)
    stripe_subscription_id = models.CharField(max_length=100, blank=True, null=True)
    start_date = models.DateTimeField(auto_now_add=True)
    end_date = models.DateTimeField()

    def __str__(self):
        return f"{self.user.username} - {self.plan.name} ({self.status})"
