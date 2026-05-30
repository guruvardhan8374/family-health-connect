from .models import Conversation, UserConversation
from django.db import transaction

def get_or_create_private_conversation(user1, user2):
    """
    Finds or creates a 1-to-1 conversation between user1 and user2.
    """
    if user1.id == user2.id:
        raise ValueError("Cannot create a private conversation with yourself.")
        
    # Check if a 1:1 conversation already exists between these users
    conversations = Conversation.objects.filter(is_group=False, participants=user1).filter(participants=user2)
    if conversations.exists():
        return conversations.first()
        
    # If not, create a new conversation atomically
    with transaction.atomic():
        conversation = Conversation.objects.create(is_group=False)
        UserConversation.objects.create(user=user1, conversation=conversation)
        UserConversation.objects.create(user=user2, conversation=conversation)
        
    return conversation

def create_family_group_chat(family_group):
    """
    Creates a group conversation representing a whole family group.
    """
    conversations = Conversation.objects.filter(is_group=True, family_group=family_group)
    if conversations.exists():
        return conversations.first()
        
    with transaction.atomic():
        conversation = Conversation.objects.create(
            is_group=True,
            family_group=family_group,
            name=family_group.name,
            description=f"Official group chat for the family '{family_group.name}'."
        )
        
        # Add all currently approved members of the family
        from family.models import FamilyMembership
        memberships = FamilyMembership.objects.filter(family_group=family_group, is_approved=True)
        for m in memberships:
            UserConversation.objects.get_or_create(user=m.user, conversation=conversation)
            
    return conversation
