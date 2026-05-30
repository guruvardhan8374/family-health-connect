from django.contrib import admin
from .models import EmergencyContact, SOSAlert, NearbyHospital

@admin.register(EmergencyContact)
class EmergencyContactAdmin(admin.ModelAdmin):
    list_display = ['user', 'name', 'relation', 'phone_number']
    list_filter = ['relation']
    search_fields = ['user__username', 'name', 'phone_number']

@admin.register(SOSAlert)
class SOSAlertAdmin(admin.ModelAdmin):
    list_display = ['user', 'status', 'is_resolved', 'triggered_at', 'resolved_at', 'location_lat', 'location_lng']
    list_filter = ['status', 'is_resolved', 'triggered_at', 'resolved_at']
    search_fields = ['user__username', 'message']
    readonly_fields = ['triggered_at']

@admin.register(NearbyHospital)
class NearbyHospitalAdmin(admin.ModelAdmin):
    list_display = ['name', 'address', 'phone_number', 'latitude', 'longitude', 'distance_km']
    search_fields = ['name', 'address']
    list_filter = ['distance_km']
