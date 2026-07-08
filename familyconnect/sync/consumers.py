import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from rest_framework_simplejwt.tokens import AccessToken
from django.contrib.auth import get_user_model

User = get_user_model()


class SyncConsumer(AsyncWebsocketConsumer):
    """
    Personal real-time sync WebSocket for a single user.

    Clients connect to  ws/sync/?token=<jwt>

    Every connected client for that user is placed in the group
    'sync_user_<user_id>'.  When any model saves (via signals.py),
    a group_send fires and every client — web AND mobile — receives
    the event immediately.

    Event envelope:
        {
          "type": "settings.update" | "health.update" |
                  "family.update"   | "emergency.alert",
          "section": "<sub-section>",   // e.g. "theme", "notifications"
          "data": { ... serialized payload ... }
        }
    """

    async def connect(self):
        # ── Authenticate via ?token= query param ──────────────────────────
        qs = self.scope.get('query_string', b'').decode()
        token_str = ''
        for part in qs.split('&'):
            if part.startswith('token='):
                token_str = part[len('token='):]
                break

        self.user = await self._get_user(token_str)
        if self.user is None or not self.user.is_authenticated:
            await self.close(code=4001)
            return

        # ── Join personal group ────────────────────────────────────────────
        self.group_name = f'sync_user_{self.user.id}'
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    # ── Receive from client (not required for push-only model, but kept for
    #    future bi-directional use, e.g. ping/ack) ─────────────────────────
    async def receive(self, text_data):
        pass  # clients are receivers only; mutations happen via REST

    # ── Dispatch handlers — one per event type ────────────────────────────

    async def settings_update(self, event):
        """Relay a settings change to this WebSocket client."""
        await self.send(text_data=json.dumps({
            'type': 'settings.update',
            'section': event.get('section'),
            'data': event.get('data', {}),
        }))

    async def health_update(self, event):
        """Relay a health record change."""
        await self.send(text_data=json.dumps({
            'type': 'health.update',
            'section': event.get('section', 'records'),
            'data': event.get('data', {}),
        }))

    async def family_update(self, event):
        """Relay a family membership / group change."""
        await self.send(text_data=json.dumps({
            'type': 'family.update',
            'section': event.get('section', 'members'),
            'data': event.get('data', {}),
        }))

    async def emergency_alert(self, event):
        """Relay an SOS alert to all connected clients of the user."""
        await self.send(text_data=json.dumps({
            'type': 'emergency.alert',
            'section': event.get('section', 'sos'),
            'data': event.get('data', {}),
        }))

    # ── Helpers ───────────────────────────────────────────────────────────

    @database_sync_to_async
    def _get_user(self, token_str: str):
        try:
            access_token = AccessToken(token_str)
            return User.objects.get(id=access_token['user_id'])
        except Exception:
            return None
