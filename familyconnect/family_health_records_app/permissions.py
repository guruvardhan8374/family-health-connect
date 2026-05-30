from rest_framework import permissions
from family.models import FamilyMembership

class IsOwnerOrFamilyAdmin(permissions.BasePermission):
    """
    Custom permission:
    - User can manage their own health records (CRUD).
    - Family admins of user's family groups can read user's health records.
    """
    def has_object_permission(self, request, view, obj):
        if not request.user or not request.user.is_authenticated:
            return False
            
        # Owner has full permission
        if obj.user == request.user:
            return True
            
        # Safe read-only checks for family admins
        if request.method in permissions.SAFE_METHODS:
            # Find common families where target user is member and requester is admin
            requester_admin_families = FamilyMembership.objects.filter(
                user=request.user, 
                is_admin=True, 
                is_approved=True
            ).values_list('family_group_id', flat=True)
            
            is_common_family_admin = FamilyMembership.objects.filter(
                user=obj.user,
                family_group_id__in=requester_admin_families,
                is_approved=True
            ).exists()
            
            return is_common_family_admin
            
        return False
