import json
import logging
from urllib.parse import parse_qs

from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async

logger = logging.getLogger(__name__)


class HealthConsumer(AsyncJsonWebsocketConsumer):
    """
    WebSocket consumer for real-time health vitals.

    URL: ws/health/?token=<access_token>

    Clients join two groups:
      - health_{user_id}          — receives updates for this user only
      - family_health_{family_id} — receives updates from all family members

    Incoming message types the client can send:
      { "type": "health.vitals", "data": { ... snapshot fields ... } }

    Outgoing events the server pushes:
      { "type": "health.update", "snapshot": { ... } }
      { "type": "health.alert",  "alerts":   [ ... ] }
    """

    async def connect(self):
        # Authenticate via JWT token in query string
        user = await self._get_user()
        if user is None:
            await self.close(code=4001)
            return

        self.user = user
        self.personal_group = f'health_{user.id}'

        # Get user's family groups
        family_ids = await self._get_family_ids(user)
        self.family_groups = [f'family_health_{fid}' for fid in family_ids]

        # Join groups
        await self.channel_layer.group_add(self.personal_group, self.channel_name)
        for fg in self.family_groups:
            await self.channel_layer.group_add(fg, self.channel_name)

        await self.accept()
        logger.info(f'HealthConsumer connected: user={user.username}')

    async def disconnect(self, close_code):
        if hasattr(self, 'personal_group'):
            await self.channel_layer.group_discard(self.personal_group, self.channel_name)
        if hasattr(self, 'family_groups'):
            for fg in self.family_groups:
                await self.channel_layer.group_discard(fg, self.channel_name)

    async def receive_json(self, content, **kwargs):
        """Handle incoming messages from the client (e.g. Flutter mobile sending vitals)."""
        msg_type = content.get('type', '')

        if msg_type == 'health.vitals':
            # Save the snapshot and broadcast back to all connected clients
            data = content.get('data', {})
            snapshot = await self._save_snapshot(data)
            if snapshot:
                payload = {
                    'type': 'health.update',
                    'snapshot': {
                        'id': snapshot.id,
                        'user_id': snapshot.user.id,
                        'recorded_at': snapshot.recorded_at.isoformat(),
                        'heart_rate': snapshot.heart_rate,
                        'steps': snapshot.steps,
                        'calories': snapshot.calories,
                        'distance': snapshot.distance,
                        'sleep_hours': snapshot.sleep_hours,
                        'spo2': snapshot.spo2,
                        'hydration': snapshot.hydration,
                        'weight': snapshot.weight,
                        'height': snapshot.height,
                        'bmi': snapshot.bmi,
                        'blood_pressure': snapshot.blood_pressure,
                    },
                }
                await self.channel_layer.group_send(self.personal_group, payload)
                for fg in self.family_groups:
                    await self.channel_layer.group_send(fg, payload)

    # ── Group event handlers (called by channel layer) ─────────────────────

    async def health_update(self, event):
        """Forward health.update group messages to this WebSocket client."""
        await self.send_json({
            'type': 'health.update',
            'snapshot': event.get('snapshot'),
        })

    async def health_alert(self, event):
        """Forward health.alert group messages to this WebSocket client."""
        await self.send_json({
            'type': 'health.alert',
            'alerts': event.get('alerts', []),
        })

    # ── Helpers ───────────────────────────────────────────────────────────

    async def _get_user(self):
        """Authenticate via ?token= query param using SimpleJWT."""
        try:
            from rest_framework_simplejwt.tokens import AccessToken
            from django.contrib.auth import get_user_model

            qs = parse_qs(self.scope['query_string'].decode())
            token_str = qs.get('token', [None])[0]
            if not token_str:
                return None

            token = AccessToken(token_str)
            user_id = token.get('user_id')
            User = get_user_model()
            return await database_sync_to_async(User.objects.get)(id=user_id)
        except Exception as e:
            logger.warning(f'HealthConsumer auth failed: {e}')
            return None

    @database_sync_to_async
    def _get_family_ids(self, user):
        from family.models import FamilyMembership
        return list(
            FamilyMembership.objects.filter(
                user=user, status='ACTIVE', is_approved=True
            ).values_list('family_group_id', flat=True)
        )

    @database_sync_to_async
    def _save_snapshot(self, data):
        from .models import HealthSnapshot
        from .views import _check_and_create_alerts
        try:
            snapshot = HealthSnapshot.objects.create(
                user=self.user,
                source=data.get('source', 'HEALTH_CONNECT'),
                heart_rate=data.get('heart_rate'),
                steps=data.get('steps'),
                calories=data.get('calories'),
                distance=data.get('distance'),
                sleep_hours=data.get('sleep_hours'),
                spo2=data.get('spo2'),
                hydration=data.get('hydration'),
                weight=data.get('weight'),
                height=data.get('height'),
                blood_pressure=data.get('blood_pressure'),
                notes=data.get('notes', ''),
                sleep_light=data.get('sleep_light'),
                sleep_deep=data.get('sleep_deep'),
                sleep_rem=data.get('sleep_rem'),
                sleep_awake=data.get('sleep_awake'),
                body_fat=data.get('body_fat'),
                exercise_count=data.get('exercise_count', 0),
                device_name=data.get('device_name', ''),
            )
            _check_and_create_alerts(snapshot)
            return snapshot
        except Exception as e:
            logger.error(f'Failed to save snapshot via WebSocket: {e}')
            return None
