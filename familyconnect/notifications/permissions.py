from rest_framework import permissions

class IsNotificationOwner(permissions.BasePermission):
    """
    Custom permission to only allow owners of a notification or reminder to view/edit it.
    """
    def has_object_permission(self, request, view, obj):
        if not request.user or not request.user.is_authenticated:
            return False
            
        return obj.user == request.user
