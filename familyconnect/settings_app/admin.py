from django.contrib import admin
from .models import (
    UserProfileSettings, NotificationSettings,
    PrivacySettings, ThemeSettings, AccountSettings
)


@admin.register(UserProfileSettings)
class UserProfileSettingsAdmin(admin.ModelAdmin):
    list_display = ('user', 'phone_number', 'timezone', 'updated_at')
    search_fields = ('user__username', 'phone_number')


@admin.register(NotificationSettings)
class NotificationSettingsAdmin(admin.ModelAdmin):
    list_display = ('user', 'push_notifications', 'medicine_reminders', 'updated_at')


@admin.register(PrivacySettings)
class PrivacySettingsAdmin(admin.ModelAdmin):
    list_display = ('user', 'profile_visibility', 'health_data_visibility', 'location_sharing', 'updated_at')


@admin.register(ThemeSettings)
class ThemeSettingsAdmin(admin.ModelAdmin):
    list_display = ('user', 'dark_mode', 'theme_color', 'updated_at')


@admin.register(AccountSettings)
class AccountSettingsAdmin(admin.ModelAdmin):
    list_display = ('user', 'two_factor_auth_enabled', 'delete_account_enabled', 'change_password_enabled', 'updated_at')
