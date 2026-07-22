import json
import logging
from urllib.parse import parse_qs

from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async
from rest_framework_simplejwt.tokens import AccessToken
from django.contrib.auth import get_user_model

logger = logging.getLogger(__name__)
User = get_user_model()


class SyncConsumer(AsyncJsonWebsocketConsumer):
    """
    Personal real-time sync WebSocket for a single user.

    Clients connect to  ws/sync/?token=<jwt>

    Every connected client for that user is placed in the group
    'sync_user_<user_id>'.  When any model saves (via signals.py),
    a group_send fires and every client — web AND mobile — receives
    the event immediately.

    Event envelope (outgoing):
        {
          "type": "settings.update" | "health.update" | "health.snapshot" |
                  "family.update"   | "emergency.alert" | "chat.message" |
                  "notification.new" | "reminder.update" | "location.update",
          "section": "<sub-section>",
          "data": { ... serialized payload ... }
        }

    Incoming client messages:
        { "type": "ping" }  → pong
        { "type": "ack", "event_id": "..." }  → reserved
    """

    async def connect(self):
        qs = parse_qs(self.scope.get('query_string', b'').decode())
        token_str = qs.get('token', [None])[0] or ''

        self.user = await self._get_user(token_str)
        if self.user is None or not self.user.is_authenticated:
            await self.close(code=4001)
            return

        self.group_name = f'sync_user_{self.user.id}'
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()
        logger.info(f'[SyncConsumer] connected: user={self.user.username}')

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive_json(self, content, **kwargs):
        msg_type = content.get('type', '')
        if msg_type == 'ping':
            await self.send_json({'type': 'pong'})

    # ── Relay handlers — one per signal event type ────────────────────────────

    async def settings_update(self, event):
        await self.send_json({
            'type': 'settings.update',
            'section': event.get('section'),
            'data': event.get('data', {}),
        })

    async def health_update(self, event):
        await self.send_json({
            'type': 'health.update',
            'section': event.get('section', 'records'),
            'data': event.get('data', {}),
        })

    async def family_update(self, event):
        await self.send_json({
            'type': 'family.update',
            'section': event.get('section', 'members'),
            'data': event.get('data', {}),
        })

    async def emergency_alert(self, event):
        await self.send_json({
            'type': 'emergency.alert',
            'section': event.get('section', 'sos'),
            'data': event.get('data', {}),
        })

    async def chat_message(self, event):
        """Real-time new chat message pushed to all conversation participants."""
        await self.send_json({
            'type': 'chat.message',
            'section': event.get('section', 'new'),
            'data': event.get('data', {}),
        })

    async def notification_new(self, event):
        """New push notification for this user."""
        await self.send_json({
            'type': 'notification.new',
            'section': event.get('section', 'push'),
            'data': event.get('data', {}),
        })

    async def reminder_update(self, event):
        """Medicine / water / sleep reminder created or updated."""
        await self.send_json({
            'type': 'reminder.update',
            'section': event.get('section', 'medicine'),
            'data': event.get('data', {}),
        })

    async def location_update(self, event):
        """Live GPS location update for a family member."""
        await self.send_json({
            'type': 'location.update',
            'section': event.get('section', 'gps'),
            'data': event.get('data', {}),
        })

    async def profile_picture_updated(self, event):
        """Profile picture created, updated, or removed."""
        await self.send_json({
            'type': 'profile.picture_updated',
            'section': event.get('section', 'avatar'),
            'data': event.get('data', {}),
        })

    async def ai_history_update(self, event):
        """AI Assistant history record created or updated."""
        await self.send_json({
            'type': 'ai.history_update',
            'section': event.get('section', 'history'),
            'data': event.get('data', {}),
        })

    # ── Helpers ───────────────────────────────────────────────────────────────

    @database_sync_to_async
    def _get_user(self, token_str: str):
        try:
            access_token = AccessToken(token_str)
            return User.objects.get(id=access_token['user_id'])
        except Exception:
            return None
