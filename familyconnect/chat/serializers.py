from rest_framework import serializers
from .models import Conversation, Message, UserConversation, Story
from users.serializers import UserSerializer

class StorySerializer(serializers.ModelSerializer):
    username = serializers.ReadOnlyField(source='user.username')
    profile_picture = serializers.ReadOnlyField(source='user.profile_picture')
    
    class Meta:
        model = Story
        fields = '__all__'
        read_only_fields = ['id', 'user', 'created_at', 'expires_at', 'viewers']

class MessageSerializer(serializers.ModelSerializer):
    sender_details = UserSerializer(source='sender', read_only=True)
    
    class Meta:
        model = Message
        fields = [
            'id', 'conversation', 'sender', 'sender_details', 'content', 
            'message_type', 'media_url', 'health_data', 'reply_to', 
            'timestamp', 'status', 'is_read'
        ]
        read_only_fields = ['id', 'sender', 'timestamp']

class UserConversationSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserConversation
        fields = ['is_pinned', 'is_archived', 'unread_count', 'joined_at']

class ConversationSerializer(serializers.ModelSerializer):
    participants_details = UserSerializer(source='participants', many=True, read_only=True)
    latest_message = serializers.SerializerMethodField()
    user_settings = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            'id', 'family_group', 'participants', 'participants_details', 
            'created_at', 'is_group', 'name', 'description', 'group_photo',
            'latest_message', 'user_settings'
        ]
        read_only_fields = ['id', 'created_at']

    def get_latest_message(self, obj):
        message = obj.messages.order_by('-timestamp').first()
        if message:
            return MessageSerializer(message).data
        return None

    def get_user_settings(self, obj):
        request = self.context.get('request')
        if request and request.user:
            try:
                user_conv = UserConversation.objects.get(user=request.user, conversation=obj)
                return UserConversationSerializer(user_conv).data
            except UserConversation.DoesNotExist:
                return None
        return None

class CreateConversationSerializer(serializers.Serializer):
    recipient_id = serializers.IntegerField(required=True)

class CreateGroupSerializer(serializers.Serializer):
    family_group_id = serializers.IntegerField(required=True)
    name = serializers.CharField(max_length=255, required=False)
    description = serializers.CharField(required=False)
