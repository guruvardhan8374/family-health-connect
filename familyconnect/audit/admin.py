from django.contrib import admin
from .models import AuditLog

@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ['user', 'action', 'resource', 'ip_address', 'timestamp']
    list_filter = ['action', 'timestamp']
    search_fields = ['user__username', 'resource', 'details']
    readonly_fields = ['user', 'action', 'resource', 'ip_address', 'user_agent', 'timestamp', 'details']
