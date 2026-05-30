from rest_framework import permissions

class CanManageEmergencyContacts(permissions.BasePermission):
    """
    Custom permission to only allow owner of the contacts list to view or edit contacts.
    """
    def has_object_permission(self, request, view, obj):
        if not request.user or not request.user.is_authenticated:
            return False
            
        return obj.user == request.user
