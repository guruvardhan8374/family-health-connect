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
