from django.contrib import admin
from .models import Notification, Reminder

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['user', 'type', 'title', 'is_read', 'priority', 'created_at']
    list_filter = ['type', 'is_read', 'priority', 'created_at']
    search_fields = ['user__username', 'title', 'message']

@admin.register(Reminder)
class ReminderAdmin(admin.ModelAdmin):
    list_display = ['user', 'reminder_type', 'title', 'time', 'is_active', 'created_at']
    list_filter = ['reminder_type', 'is_active', 'created_at']
    search_fields = ['user__username', 'title', 'message']
