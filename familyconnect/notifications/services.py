from .models import Notification, Reminder
from django.utils import timezone

def create_notification(user, type, title, message, data=None, priority='NORMAL'):
    """
    Creates a single in-app notification.
    """
    if data is None:
        data = {}
    return Notification.objects.create(
        user=user,
        type=type,
        title=title,
        message=message,
        data=data,
        priority=priority
    )

def create_bulk_notifications(users, type, title, message, data=None, priority='NORMAL'):
    """
    Helper to bulk-create notifications for list of users (e.g. family announcements).
    """
    if data is None:
        data = {}
    notifications = [
        Notification(
            user=user,
            type=type,
            title=title,
            message=message,
            data=data,
            priority=priority
        ) for user in users
    ]
    return Notification.objects.bulk_create(notifications)

def get_due_reminders():
    """
    Query for all active reminders due around current local time.
    """
    now = timezone.now()
    current_time = now.time()
    current_weekday = now.strftime('%A') # e.g. "Monday"
    
    # Simple check for reminders matching within current hour/minute bucket
    # and repeat days includes current weekday (or repeat_days is empty for every day)
    active_reminders = Reminder.objects.filter(is_active=True, time__hour=current_time.hour, time__minute=current_time.minute)
    
    due = []
    for r in active_reminders:
        if not r.repeat_days or current_weekday in r.repeat_days:
            due.append(r)
            
    return due

_firebase_initialized = False

def init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return True
    try:
        import firebase_admin
        firebase_admin.initialize_app()
        _firebase_initialized = True
        return True
    except Exception as e:
        try:
            import os
            from firebase_admin import credentials
            cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
            if cred_path and os.path.exists(cred_path):
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)
                _firebase_initialized = True
                return True
        except Exception:
            pass
        print(f"[FCM] Firebase initialization skipped/unconfigured: {e}")
    return False

def send_fcm_notification(user, title, message, data=None):
    """
    Sends a high-priority FCM push notification to the user's registered device.
    """
    if data is None:
        data = {}
    
    fcm_token = None
    try:
        if hasattr(user, 'settings') and user.settings.notification_prefs:
            fcm_token = user.settings.notification_prefs.get('fcm_token')
    except Exception:
        pass
    
    if not fcm_token:
        print(f"[FCM] No token registered for user: {user.username}. WebSockets will handle live notification.")
        return False

    if not init_firebase():
        print(f"[FCM] Push skipped: Firebase Admin unconfigured.")
        return False

    try:
        import firebase_admin
        from firebase_admin import messaging
        
        android_config = messaging.AndroidConfig(
            priority='high',
            notification=messaging.AndroidNotification(
                sound='default',
                default_sound=True,
                default_vibrate_timings=True,
            )
        )
        
        stringified_data = {k: str(v) for k, v in data.items()}

        msg = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=message,
            ),
            android=android_config,
            data=stringified_data,
            token=fcm_token,
        )
        
        messaging.send(msg)
        print(f"[FCM] Push successfully sent to user {user.username}")
        return True
    except Exception as e:
        print(f"[FCM] Failed to send push to user {user.username}: {e}")
        return False
