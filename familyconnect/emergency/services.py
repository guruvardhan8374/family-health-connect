from family_health_records_app.models import HealthRecord
from family.models import FamilyMembership
from notifications.services import create_notification

def get_vitals_snapshot(user):
    """
    Captures a snapshot of the user's latest health metrics to attach to an SOS alert.
    """
    recent = HealthRecord.objects.filter(user=user).order_by('-recorded_date', '-created_at').first()
    if not recent:
        return {
            "heart_rate": 0,
            "oxygen_level": 0,
            "blood_pressure": "Unknown"
        }
        
    return {
        "heart_rate": recent.heart_rate,
        "oxygen_level": recent.oxygen_level,
        "blood_pressure": recent.blood_pressure,
        "recorded_at": recent.created_at.isoformat() if recent.created_at else None
    }

def notify_family_members(sos_alert):
    """
    Broadcasts high-priority notifications to all approved members in the user's family groups.
    """
    user = sos_alert.user
    
    # Get all unique approved family groups the user is part of
    family_group_ids = FamilyMembership.objects.filter(
        user=user, 
        is_approved=True
    ).values_list('family_group_id', flat=True)
    
    # Find all members in these family groups (excluding the sender)
    recipients = FamilyMembership.objects.filter(
        family_group_id__in=family_group_ids,
        is_approved=True
    ).exclude(user=user).select_related('user')
    
    notified_users = set()
    
    for member in recipients:
        if member.user not in notified_users:
            create_notification(
                user=member.user,
                type='EMERGENCY',
                title='🚨 EMERGENCY SOS ALERT!',
                message=f"{user.username} has triggered an SOS alert! Message: {sos_alert.message}",
                priority='URGENT',
                data={
                    'sos_alert_id': sos_alert.id,
                    'latitude': sos_alert.location_lat,
                    'longitude': sos_alert.location_lng,
                    'vitals': sos_alert.vitals_snapshot
                }
            )
            notified_users.add(member.user)
            
    return len(notified_users)
