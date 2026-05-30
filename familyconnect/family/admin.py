from django.contrib import admin
from .models import FamilyGroup, FamilyMembership, SafeZone, FamilyInvitation

@admin.register(FamilyGroup)
class FamilyGroupAdmin(admin.ModelAdmin):
    list_display = ['name', 'family_code', 'max_members', 'created_by', 'created_at']
    search_fields = ['name', 'family_code', 'created_by__username']
    list_filter = ['created_at']

@admin.register(FamilyMembership)
class FamilyMembershipAdmin(admin.ModelAdmin):
    list_display = ['user', 'family_group', 'is_admin', 'is_approved', 'label', 'joined_at']
    list_filter = ['is_admin', 'is_approved', 'label', 'joined_at']
    search_fields = ['user__username', 'family_group__name']

@admin.register(SafeZone)
class SafeZoneAdmin(admin.ModelAdmin):
    list_display = ['name', 'family_group', 'latitude', 'longitude', 'radius_meters']
    search_fields = ['name', 'family_group__name']

@admin.register(FamilyInvitation)
class FamilyInvitationAdmin(admin.ModelAdmin):
    list_display = ['invited_email', 'family_group', 'invited_by', 'status', 'created_at', 'expires_at']
    list_filter = ['status', 'created_at', 'expires_at']
    search_fields = ['invited_email', 'family_group__name', 'invited_by__username']
