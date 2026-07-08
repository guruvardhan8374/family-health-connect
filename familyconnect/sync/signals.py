"""
sync/signals.py
───────────────
Django post_save signals that push real-time updates to every client
connected via SyncConsumer.

Each signal handler:
  1. Gets the async channel layer synchronously via async_to_sync
  2. Sends a group_send() to  'sync_user_<user_id>'
  3. The SyncConsumer receives the event and forwards it to every
     WebSocket (web browser + mobile app) belonging to that user.

Supported models
────────────────
  Settings:   ThemeSettings, NotificationSettings, PrivacySettings,
              UserProfileSettings
  Health:     HealthMetric, HealthAlert
  Emergency:  SOSAlert
  Family:     FamilyMembership
  Chat:       Message  (supplements the existing ChatConsumer broadcast)
"""

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.db.models.signals import post_save
from django.dispatch import receiver


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _push(user_id, event_type, section, data):
    """Fire-and-forget group_send to a user's personal sync group."""
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return
    # Convert dots to underscores for the channel layer handler name
    handler_name = event_type.replace('.', '_')
    async_to_sync(channel_layer.group_send)(
        f'sync_user_{user_id}',
        {
            'type': handler_name,   # maps to SyncConsumer.settings_update etc.
            'section': section,
            'data': data,
        }
    )


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
            'created_at': instance.created_at.isoformat(),
        })


# ─── Emergency signals ─────────────────────────────────────────────────────────

@receiver(post_save, sender='emergency.SOSAlert')
def on_sos_saved(sender, instance, created, **kwargs):
    if created:
        _push(instance.user_id, 'emergency.alert', 'sos', {
            'id': instance.id,
            'message': instance.message,
            'location_lat': instance.location_lat,
            'location_lng': instance.location_lng,
            'triggered_at': instance.triggered_at.isoformat(),
            'status': instance.status,
            'triggered_by': instance.user.username if instance.user else None,
        })


# ─── Family signals ────────────────────────────────────────────────────────────

@receiver(post_save, sender='family.FamilyMembership')
def on_membership_saved(sender, instance, created, **kwargs):
    if created:
        # Notify every member of the group about the new member
        from family.models import FamilyMembership
        member_ids = FamilyMembership.objects.filter(
            family_group=instance.family_group
        ).values_list('user_id', flat=True)

        payload = {
            'group_id': instance.family_group_id,
            'group_name': instance.family_group.name,
            'new_member_id': instance.user_id,
            'new_member_username': instance.user.username if instance.user else None,
            'label': instance.label,
        }
        for uid in member_ids:
            _push(uid, 'family.update', 'members', payload)
