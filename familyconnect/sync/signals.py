"""
sync/signals.py
───────────────
Django post_save signals that push real-time updates to every client
connected via SyncConsumer (ws/sync/?token=<jwt>).

Covered models
──────────────
  Settings:      ThemeSettings, NotificationSettings, PrivacySettings,
                 UserProfileSettings
  Health:        HealthMetric, HealthAlert, HealthSnapshot, HealthRecord
  Emergency:     SOSAlert
  Family:        FamilyMembership
  Chat:          Message  (supplements the existing ChatConsumer broadcast)
  Notifications: Notification, Reminder
  Location:      LocationHistory  (pushed to every family-group member)
"""

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.db.models.signals import post_save
from django.dispatch import receiver
import logging

logger = logging.getLogger(__name__)


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _push(user_id, event_type, section, data):
    """Fire-and-forget group_send to a user's personal sync group."""
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return
    try:
        handler_name = event_type.replace('.', '_')
        async_to_sync(channel_layer.group_send)(
            f'sync_user_{user_id}',
            {
                'type': handler_name,
                'section': section,
                'data': data,
            }
        )
    except Exception as e:
        logger.warning(f'[sync] _push failed for user {user_id}: {e}')


def _push_to_family(family_group, event_type, section, data):
    """Push the same event to every member of a family group."""
    try:
        from family.models import FamilyMembership
        member_ids = FamilyMembership.objects.filter(
            family_group=family_group,
            is_approved=True,
        ).values_list('user_id', flat=True)
        for uid in member_ids:
            _push(uid, event_type, section, data)
    except Exception as e:
        logger.warning(f'[sync] _push_to_family failed: {e}')


# ─── Settings signals ──────────────────────────────────────────────────────────

@receiver(post_save, sender='settings_app.ThemeSettings')
def on_theme_saved(sender, instance, **kwargs):
    _push(instance.user_id, 'settings.update', 'theme', {
        'dark_mode': instance.dark_mode,
        'theme_color': instance.theme_color,
    })


@receiver(post_save, sender='settings_app.NotificationSettings')
def on_notifications_saved(sender, instance, **kwargs):
    _push(instance.user_id, 'settings.update', 'notifications', {
        'push_notifications': instance.push_notifications,
        'medicine_reminders': instance.medicine_reminders,
        'health_reminders': instance.health_reminders,
        'emergency_alerts': instance.emergency_alerts,
        'family_notifications': instance.family_notifications,
        'chat_notifications': instance.chat_notifications,
        'email_notifications': instance.email_notifications,
    })


@receiver(post_save, sender='settings_app.PrivacySettings')
def on_privacy_saved(sender, instance, **kwargs):
    _push(instance.user_id, 'settings.update', 'privacy', {
        'profile_visibility': instance.profile_visibility,
        'health_data_visibility': instance.health_data_visibility,
        'family_visibility': instance.family_visibility,
        'location_sharing': instance.location_sharing,
        'emergency_visibility': instance.emergency_visibility,
    })

    # Broadcast location update to family members so their maps reflect privacy changes immediately
    try:
        from django.utils import timezone
        latest = instance.user.location_history.order_by('-timestamp').first()
        is_sharing = instance.location_sharing
        full_name = instance.user.get_full_name() or instance.user.username
        loc_payload = {
            'user_id': instance.user_id,
            'username': instance.user.username,
            'full_name': full_name,
            'profile_picture': instance.user.profile_picture,
            'latitude': latest.latitude if latest else 0.0,
            'longitude': latest.longitude if latest else 0.0,
            'speed': getattr(latest, 'speed', 0.0) if latest else 0.0,
            'battery_level': getattr(latest, 'battery_level', 100) if latest else 100,
            'is_moving': getattr(latest, 'is_moving', False) if latest else False,
            'timestamp': latest.timestamp.isoformat() if latest else timezone.now().isoformat(),
            'is_online': is_sharing and (latest is not None),
            'is_sharing_enabled': is_sharing,
            'last_seen_formatted': 'Just now' if (is_sharing and latest) else 'Sharing disabled',
        }
        from family.models import FamilyMembership
        family_ids = FamilyMembership.objects.filter(
            user_id=instance.user_id, is_approved=True
        ).values_list('family_group_id', flat=True)
        for fid in family_ids:
            _push_to_family_group_id(fid, 'location.update', 'gps', loc_payload, exclude_user=instance.user_id)
    except Exception as e:
        logger.warning(f'[sync] privacy location push failed: {e}')



@receiver(post_save, sender='settings_app.UserProfileSettings')
def on_profile_saved(sender, instance, **kwargs):
    _push(instance.user_id, 'settings.update', 'profile', {
        'phone_number': instance.phone_number,
        'bio': instance.bio,
        'emergency_contact': instance.emergency_contact,
        'emergency_phone': instance.emergency_phone,
        'preferred_language': instance.preferred_language,
        'timezone': instance.timezone,
        'date_of_birth': str(instance.date_of_birth) if instance.date_of_birth else None,
        'gender': instance.gender,
        'blood_group': instance.blood_group,
        'address': instance.address,
        'profile_picture': instance.profile_picture,
    })


# ─── Health signals ────────────────────────────────────────────────────────────

@receiver(post_save, sender='health.HealthMetric')
def on_health_metric_saved(sender, instance, created, **kwargs):
    if created:
        _push(instance.user_id, 'health.update', 'metric', {
            'id': instance.id,
            'metric_type': instance.metric_type,
            'value': instance.value,
            'unit': instance.unit,
            'recorded_at': instance.recorded_at.isoformat(),
        })


@receiver(post_save, sender='health.HealthAlert')
def on_health_alert_saved(sender, instance, created, **kwargs):
    if created:
        _push(instance.user_id, 'health.update', 'alert', {
            'id': instance.id,
            'title': instance.title,
            'message': instance.message,
            'severity': getattr(instance, 'severity', 'HIGH'),
            'alert_type': getattr(instance, 'alert_type', ''),
            'created_at': instance.created_at.isoformat(),
        })


@receiver(post_save, sender='health.HealthSnapshot')
def on_health_snapshot_saved(sender, instance, created, **kwargs):
    """Push live vitals to the user AND all family members."""
    data = {
        'id': instance.id,
        'source': instance.source,
        'recorded_at': instance.recorded_at.isoformat(),
        'heart_rate': instance.heart_rate,
        'steps': instance.steps,
        'calories': instance.calories,
        'distance': instance.distance,
        'sleep_hours': instance.sleep_hours,
        'spo2': instance.spo2,
        'hydration': instance.hydration,
        'weight': instance.weight,
        'bmi': instance.bmi,
        'blood_pressure': instance.blood_pressure,
        'user_id': instance.user_id,
    }
    # Push to the owner
    _push(instance.user_id, 'health.update', 'snapshot', data)

    # Push to all family members (they see this person's vitals in Family view)
    try:
        from family.models import FamilyMembership
        family_ids = FamilyMembership.objects.filter(
            user_id=instance.user_id, is_approved=True
        ).values_list('family_group_id', flat=True)
        for fid in family_ids:
            _push_to_family_group_id(fid, 'health.update', 'snapshot', data, exclude_user=instance.user_id)
    except Exception as e:
        logger.warning(f'[sync] snapshot family push failed: {e}')


def _push_to_family_group_id(family_group_id, event_type, section, data, exclude_user=None):
    """Push event to all members of a group by group ID."""
    try:
        from family.models import FamilyMembership
        qs = FamilyMembership.objects.filter(
            family_group_id=family_group_id, is_approved=True
        ).values_list('user_id', flat=True)
        for uid in qs:
            if exclude_user and uid == exclude_user:
                continue
            _push(uid, event_type, section, data)
    except Exception as e:
        logger.warning(f'[sync] _push_to_family_group_id failed: {e}')


@receiver(post_save, sender='family_health_records_app.HealthRecord')
def on_health_record_saved(sender, instance, created, **kwargs):
    action = 'created' if created else 'updated'
    _push(instance.user_id, 'health.update', 'record', {
        'id': instance.id,
        'action': action,
        'record_type': getattr(instance, 'record_type', ''),
        'title': getattr(instance, 'title', ''),
        'recorded_date': str(getattr(instance, 'recorded_date', '')),
    })


# ─── Emergency signals ─────────────────────────────────────────────────────────

@receiver(post_save, sender='emergency.SOSAlert')
def on_sos_saved(sender, instance, created, **kwargs):
    payload = {
        'id': instance.id,
        'message': instance.message,
        'location_lat': instance.location_lat,
        'location_lng': instance.location_lng,
        'triggered_at': instance.triggered_at.isoformat(),
        'status': instance.status,
        'triggered_by': instance.user.username if instance.user else None,
        'user_id': instance.user_id,
        'is_resolved': getattr(instance, 'is_resolved', False),
    }
    _push(instance.user_id, 'emergency.alert', 'sos', payload)
    # Also notify all family members
    try:
        from family.models import FamilyMembership
        family_ids = FamilyMembership.objects.filter(
            user_id=instance.user_id, is_approved=True
        ).values_list('family_group_id', flat=True)
        for fid in family_ids:
            _push_to_family_group_id(fid, 'emergency.alert', 'sos', payload, exclude_user=instance.user_id)
    except Exception:
        pass


# ─── Family signals ────────────────────────────────────────────────────────────

@receiver(post_save, sender='family.FamilyMembership')
def on_membership_saved(sender, instance, created, **kwargs):
    if created:
        try:
            from family.models import FamilyMembership
            member_ids = FamilyMembership.objects.filter(
                family_group=instance.family_group
            ).values_list('user_id', flat=True)

            payload = {
                'group_id': instance.family_group_id,
                'group_name': instance.family_group.name if instance.family_group else '',
                'new_member_id': instance.user_id,
                'new_member_username': instance.user.username if instance.user else None,
                'label': instance.label,
                'action': 'joined',
            }
            for uid in member_ids:
                _push(uid, 'family.update', 'members', payload)
        except Exception as e:
            logger.warning(f'[sync] family membership signal failed: {e}')


# ─── Notifications signals ─────────────────────────────────────────────────────

@receiver(post_save, sender='notifications.Notification')
def on_notification_saved(sender, instance, created, **kwargs):
    if created:
        _push(instance.user_id, 'notification.new', 'push', {
            'id': instance.id,
            'type': instance.type,
            'title': instance.title,
            'message': instance.message,
            'priority': instance.priority,
            'data': instance.data,
            'is_read': instance.is_read,
            'created_at': instance.created_at.isoformat(),
        })
        try:
            from notifications.services import send_fcm_notification
            send_fcm_notification(instance.user, instance.title, instance.message, instance.data)
        except Exception:
            pass


@receiver(post_save, sender='notifications.Reminder')
def on_reminder_saved(sender, instance, created, **kwargs):
    action = 'created' if created else 'updated'
    _push(instance.user_id, 'reminder.update', 'medicine', {
        'id': instance.id,
        'action': action,
        'reminder_type': instance.reminder_type,
        'title': instance.title,
        'message': instance.message,
        'time': str(instance.time),
        'repeat_days': instance.repeat_days,
        'is_active': instance.is_active,
    })


# ─── Location signals ──────────────────────────────────────────────────────────

@receiver(post_save, sender='users.LocationHistory')
def on_location_saved(sender, instance, created, **kwargs):
    if not created:
        return

    is_sharing = True
    try:
        if hasattr(instance.user, 'privacy_settings'):
            is_sharing = instance.user.privacy_settings.location_sharing
    except Exception:
        pass

    full_name = ''
    if instance.user:
        full_name = instance.user.get_full_name() or instance.user.username

    payload = {
        'user_id': instance.user_id,
        'username': instance.user.username if instance.user else None,
        'full_name': full_name,
        'profile_picture': instance.user.profile_picture if instance.user else None,
        'latitude': instance.latitude,
        'longitude': instance.longitude,
        'speed': getattr(instance, 'speed', 0.0) or 0.0,
        'battery_level': getattr(instance, 'battery_level', 100) or 100,
        'is_moving': getattr(instance, 'is_moving', False),
        'timestamp': instance.timestamp.isoformat(),
        'is_online': True,
        'is_sharing_enabled': is_sharing,
        'last_seen_formatted': 'Just now',
    }
    # Push to self
    _push(instance.user_id, 'location.update', 'gps', payload)

    # Push to all family members in same groups
    try:
        from family.models import FamilyMembership
        family_ids = FamilyMembership.objects.filter(
            user_id=instance.user_id, is_approved=True
        ).values_list('family_group_id', flat=True)
        for fid in family_ids:
            _push_to_family_group_id(fid, 'location.update', 'gps', payload, exclude_user=instance.user_id)
    except Exception as e:
        logger.warning(f'[sync] location family push failed: {e}')


# ─── Chat Message signals ──────────────────────────────────────────────────────

@receiver(post_save, sender='chat.Message')
def on_chat_message_saved(sender, instance, created, **kwargs):
    """
    Supplement the existing ChatConsumer broadcast:
    ensures any Message written directly via REST (mobile app) is
    also pushed through the personal sync channel.
    """
    if not created:
        return
    try:
        # Find all participants
        from chat.models import UserConversation
        participant_ids = UserConversation.objects.filter(
            conversation=instance.conversation
        ).values_list('user_id', flat=True)

        payload = {
            'id': instance.id,
            'conversation_id': instance.conversation_id,
            'sender_id': instance.sender_id,
            'sender_username': instance.sender.username if instance.sender else None,
            'content': instance.content,
            'message_type': instance.message_type,
            'media_url': instance.media_url,
            'timestamp': instance.timestamp.isoformat(),
            'status': instance.status,
        }
        for uid in participant_ids:
            _push(uid, 'chat.message', 'new', payload)
    except Exception as e:
        logger.warning(f'[sync] chat message signal failed: {e}')


@receiver(post_save, sender='sync.AIAssistantHistory')
def on_ai_history_saved(sender, instance, created, **kwargs):
    """Pushes new AI Assistant chat turns to all connected user devices."""
    if created:
        _push(instance.user_id, 'ai.history_update', 'history', {
            'id': instance.id,
            'role': instance.role,
            'content': instance.content,
            'created_at': instance.created_at.isoformat(),
        })
