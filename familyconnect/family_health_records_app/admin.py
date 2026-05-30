from django.contrib import admin
from .models import HealthRecord

@admin.register(HealthRecord)
class HealthRecordAdmin(admin.ModelAdmin):
    list_display = ['user', 'recorded_date', 'heart_rate', 'oxygen_level', 'blood_pressure', 'steps', 'bmi', 'created_at']
    list_filter = ['recorded_date', 'created_at', 'user__role']
    search_fields = ['user__username', 'user__email', 'notes']
    date_hierarchy = 'recorded_date'
    readonly_fields = ['bmi', 'created_at']
