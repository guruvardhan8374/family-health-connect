from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import CustomUser, LocationHistory, UserSettings

@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    model = CustomUser
    list_display = ['username', 'email', 'phone_number', 'role', 'is_otp_verified', 'is_staff']
    list_filter = ['role', 'is_otp_verified', 'is_staff', 'is_superuser']
    search_fields = ['username', 'email', 'phone_number']
    fieldsets = UserAdmin.fieldsets + (
        ('Profile Information', {'fields': ('phone_number', 'profile_picture', 'role', 'date_of_birth', 'gender', 'blood_group', 'address', 'emergency_phone')}),
        ('OTP details', {'fields': ('otp_code', 'otp_created_at', 'is_otp_verified')}),
    )

@admin.register(UserSettings)
class UserSettingsAdmin(admin.ModelAdmin):
    list_display = ['user', 'theme_mode', 'language', 'created_at', 'updated_at']
    search_fields = ['user__username', 'user__email']
    list_filter = ['theme_mode', 'language']

@admin.register(LocationHistory)
class LocationHistoryAdmin(admin.ModelAdmin):
    list_display = ['user', 'latitude', 'longitude', 'timestamp']
    search_fields = ['user__username', 'user__email']
    list_filter = ['timestamp']
