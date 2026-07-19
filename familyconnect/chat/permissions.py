from rest_framework import permissions
from .models import UserConversation

class IsConversationParticipant(permissions.BasePermission):
    """
    Custom permission to only allow participants of a conversation to read or send messages in it.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if view.action == 'create':
            conversation_id = request.data.get('conversation')
            if not conversation_id:
                return True  # Let serializer validation handle missing fields
            return UserConversation.objects.filter(user=request.user, conversation_id=conversation_id).exists()
        return True

    def has_object_permission(self, request, view, obj):
        if not request.user or not request.user.is_authenticated:
            return False
            
        conversation = getattr(obj, 'conversation', obj)
        return UserConversation.objects.filter(user=request.user, conversation=conversation).exists()
