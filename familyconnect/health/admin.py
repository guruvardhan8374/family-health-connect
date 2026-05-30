from django.contrib import admin
from .models import HealthMetric, HealthAlert

admin.site.register(HealthMetric)
admin.site.register(HealthAlert)
