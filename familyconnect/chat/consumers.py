import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model
from django.db import models
from rest_framework_simplejwt.tokens import AccessToken

from .models import Conversation, Message, UserConversation

User = get_user_model()

class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.conversation_id = self.scope['url_route']['kwargs']['conversation_id']
        self.room_group_name = f"chat_{self.conversation_id}"

        # Authentication via query string token
        query_string = self.scope.get('query_string', b'').decode('utf-8')
        token = ""
        if 'token=' in query_string:
            token = query_string.split('token=')[1].split('&')[0]

        self.user = await self.get_user_from_token(token)
        
        if self.user is None or not self.user.is_authenticated:
            # Reject connection
            await self.close(code=4001)
            return

        # Check if user is a participant of the conversation
        is_participant = await self.check_participant(self.user, self.conversation_id)
        if not is_participant:
            await self.close(code=4003)
            return

        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )

        await self.accept()

    async def disconnect(self, close_code):
        # Leave room group
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name
            )

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return

        content = data.get('content')
        message_type = data.get('message_type', 'TEXT')
        media_url = data.get('media_url')
        health_data = data.get('health_data')

        if not content and not media_url and not health_data:
            return

        # Save message to database
        message = await self.save_message(
            sender=self.user,
            conversation_id=self.conversation_id,
            content=content,
            message_type=message_type,
            media_url=media_url,
            health_data=health_data
        )

        # Broadcast message to room group
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'chat_message',
                'id': message.id,
                'sender_id': self.user.id,
                'sender_username': self.user.username,
                'content': message.content,
                'message_type': message.message_type,
                'media_url': message.media_url,
                'health_data': message.health_data,
                'timestamp': message.timestamp.isoformat()
            }
        )

    # Receive message from room group
    async def chat_message(self, event):
        # Send message to WebSocket
        await self.send(text_data=json.dumps(event))

    @database_sync_to_async
    def get_user_from_token(self, token):
        try:
            access_token = AccessToken(token)
            user_id = access_token['user_id']
            return User.objects.get(id=user_id)
        except Exception:
            return None

    @database_sync_to_async
    def check_participant(self, user, conversation_id):
        return UserConversation.objects.filter(user=user, conversation_id=conversation_id).exists()

    @database_sync_to_async
    def save_message(self, sender, conversation_id, content, message_type, media_url, health_data):
        # Increment unread counts for all other participants
        UserConversation.objects.filter(conversation_id=conversation_id).exclude(user=sender).update(
            unread_count=models.F('unread_count') + 1
        )
        
        conversation = Conversation.objects.get(id=conversation_id)
        return Message.objects.create(
            conversation=conversation,
            sender=sender,
            content=content,
            message_type=message_type,
            media_url=media_url,
            health_data=health_data
        )
