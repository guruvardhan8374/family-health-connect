from rest_framework import permissions
from .models import FamilyMembership

class IsFamilyMember(permissions.BasePermission):
    """
    Allows access only to approved members of the family group.
    """
    def has_object_permission(self, request, view, obj):
        if not request.user or not request.user.is_authenticated:
            return False
            
        family_group = getattr(obj, 'family_group', obj)
        if hasattr(obj, 'family'):
            family_group = obj.family
            
        return FamilyMembership.objects.filter(
            user=request.user, 
            family_group=family_group, 
            is_approved=True
        ).exists()

class IsFamilyAdmin(permissions.BasePermission):
    """
    Allows access only to approved admins of the family group.
    """
    def has_object_permission(self, request, view, obj):
        if not request.user or not request.user.is_authenticated:
            return False
            
        family_group = getattr(obj, 'family_group', obj)
        if hasattr(obj, 'family'):
            family_group = obj.family
            
        return FamilyMembership.objects.filter(
            user=request.user, 
            family_group=family_group, 
            is_admin=True, 
            is_approved=True
        ).exists()
