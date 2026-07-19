from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser
from django.utils import timezone
from django.conf import settings
from django.db.models import Max
import os

from .models import Conversation, Message, UserConversation, Story
from .serializers import (
    ConversationSerializer, MessageSerializer, StorySerializer,
    CreateConversationSerializer, CreateGroupSerializer
)
from .permissions import IsConversationParticipant
from .services import get_or_create_private_conversation, create_family_group_chat
from users.models import CustomUser
from family.models import FamilyGroup, FamilyMembership

class ConversationViewSet(viewsets.ModelViewSet):
    serializer_class = ConversationSerializer
    permission_classes = [permissions.IsAuthenticated, IsConversationParticipant]
    pagination_class = None

    def get_queryset(self):
        # Annotate with last message timestamp to sort active chats to top
        return Conversation.objects.filter(
            participants=self.request.user
        ).annotate(
            last_message_time=Max('messages__timestamp')
        ).order_by('-last_message_time', '-created_at')

    @action(detail=False, methods=['post'], url_path='private')
    def create_private_conversation(self, request):
        serializer = CreateConversationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        recipient_id = serializer.validated_data['recipient_id']
        try:
            recipient = CustomUser.objects.get(id=recipient_id)
        except CustomUser.DoesNotExist:
            return Response({"error": "Recipient user not found"}, status=status.HTTP_404_NOT_FOUND)
            
        try:
            conversation = get_or_create_private_conversation(request.user, recipient)
            return Response(ConversationSerializer(conversation, context={'request': request}).data, status=status.HTTP_201_CREATED)
        except ValueError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['post'], url_path='group')
    def create_group_conversation(self, request):
        serializer = CreateGroupSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        family_group_id = serializer.validated_data['family_group_id']
        try:
            family_group = FamilyGroup.objects.get(id=family_group_id)
        except FamilyGroup.DoesNotExist:
            return Response({"error": "Family group not found"}, status=status.HTTP_404_NOT_FOUND)
            
        # Check if user is approved member of the family
        is_member = FamilyMembership.objects.filter(user=request.user, family_group=family_group, is_approved=True).exists()
        if not is_member:
            return Response({"error": "You must be an approved family member to create this chat"}, status=status.HTTP_403_FORBIDDEN)
            
        conversation = create_family_group_chat(family_group)
        if serializer.validated_data.get('name'):
            conversation.name = serializer.validated_data['name']
        if serializer.validated_data.get('description'):
            conversation.description = serializer.validated_data['description']
        conversation.save()
        
        return Response(ConversationSerializer(conversation, context={'request': request}).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def pin(self, request, pk=None):
        conversation = self.get_object()
        user_conv, created = UserConversation.objects.get_or_create(user=request.user, conversation=conversation)
        user_conv.is_pinned = not user_conv.is_pinned
        user_conv.save()
        return Response({'status': 'success', 'is_pinned': user_conv.is_pinned})

    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        conversation = self.get_object()
        user_conv, created = UserConversation.objects.get_or_create(user=request.user, conversation=conversation)
        user_conv.is_pinned = False
        user_conv.is_archived = not user_conv.is_archived
        user_conv.save()
        return Response({'status': 'success', 'is_archived': user_conv.is_archived})

class MessageViewSet(viewsets.ModelViewSet):
    serializer_class = MessageSerializer
    permission_classes = [permissions.IsAuthenticated, IsConversationParticipant]
    search_fields = ['content']
    pagination_class = None

    def get_queryset(self):
        conversation_id = self.request.query_params.get('conversation')
        if conversation_id:
            # Check if user is participant of conversation_id
            is_member = UserConversation.objects.filter(user=self.request.user, conversation_id=conversation_id).exists()
            if not is_member:
                return Message.objects.none()
            return Message.objects.filter(conversation_id=conversation_id).order_by('-timestamp')
        return Message.objects.none()

    def perform_create(self, serializer):
        message = serializer.save(sender=self.request.user)
        
        # Update unread count for other conversation participants
        from django.db.models import F
        UserConversation.objects.filter(conversation=message.conversation).exclude(user=self.request.user).update(
            unread_count=F('unread_count') + 1
        )

        # Broadcast via Channel Layer for real-time updates if Channels is active
        try:
            from channels.layers import get_channel_layer
            from asgiref.sync import async_to_sync
            channel_layer = get_channel_layer()
            if channel_layer:
                async_to_sync(channel_layer.group_send)(
                    f"chat_{message.conversation.id}",
                    {
                        'type': 'chat_message',
                        'id': message.id,
                        'sender_id': self.request.user.id,
                        'sender_username': self.request.user.username,
                        'content': message.content,
                        'message_type': message.message_type,
                        'media_url': message.media_url,
                        'health_data': message.health_data,
                        'timestamp': message.timestamp.isoformat()
                    }
                )
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Failed to broadcast chat message via channel layer: {e}")

    @action(detail=False, methods=['post'], url_path='mark-read')
    def mark_read(self, request):
        conversation_id = request.data.get('conversation')
        if not conversation_id:
            return Response({"error": "conversation parameter is required"}, status=status.HTTP_400_BAD_REQUEST)
            
        UserConversation.objects.filter(user=request.user, conversation_id=conversation_id).update(unread_count=0)
        Message.objects.filter(conversation_id=conversation_id).exclude(sender=request.user).update(is_read=True, status='READ')
        return Response({"status": "messages marked as read"})

class MediaUploadView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, *args, **kwargs):
        file_obj = request.data.get('file')
        if not file_obj:
            return Response({'error': 'No file uploaded'}, status=status.HTTP_400_BAD_REQUEST)
        
        media_path = os.path.join(settings.MEDIA_ROOT, 'chat_media', file_obj.name)
        os.makedirs(os.path.dirname(media_path), exist_ok=True)
        
        with open(media_path, 'wb+') as destination:
            for chunk in file_obj.chunks():
                destination.write(chunk)
        
        file_url = request.build_absolute_uri(settings.MEDIA_URL + 'chat_media/' + file_obj.name)
        return Response({'url': file_url}, status=status.HTTP_201_CREATED)

class StoryViewSet(viewsets.ModelViewSet):
    serializer_class = StorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Show stories that are still active (within 24 hours)
        return Story.objects.filter(expires_at__gt=timezone.now()).order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=True, methods=['post'])
    def mark_viewed(self, request, pk=None):
        story = self.get_object()
        story.viewers.add(request.user)
        return Response({'status': 'viewed'})