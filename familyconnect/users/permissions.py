from rest_framework import permissions

class IsOwnerOrAdmin(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object or admins to view or edit it.
    """
    def has_object_permission(self, request, view, obj):
        if not request.user or not request.user.is_authenticated:
            return False
            
        # Super admin can do anything
        if request.user.role == 'SUPER_ADMIN':
            return True
            
        # If the object itself is a CustomUser
        if hasattr(obj, 'id') and obj == request.user:
            return True
            
        # If the object has a user relationship
        if hasattr(obj, 'user') and obj.user == request.user:
            return True
            
        return False

class IsSuperAdmin(permissions.BasePermission):
    """
    Allows access only to Super Admins.
    """
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.role == 'SUPER_ADMIN'

class IsFamilyHead(permissions.BasePermission):
    """
    Allows access only to Family Heads or above.
    """
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.role in ['HEAD', 'SUPER_ADMIN', 'ORG_ADMIN']
