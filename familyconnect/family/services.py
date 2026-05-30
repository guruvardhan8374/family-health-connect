import secrets
import string
import logging

logger = logging.getLogger(__name__)

def generate_family_code():
    """
    Generates a unique 8-character alphanumeric code for a family group.
    """
    alphabet = string.ascii_uppercase + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(8))

def send_invitation_email(invitation):
    """
    Sends the family invite via email. In production, this integrates with SMTP/SES.
    Currently, it logs the invitation link details.
    """
    subject = f"Family Health Connect - Invitation to join {invitation.family_group.name}"
    invite_url = f"http://localhost:5173/join?token={invitation.token}"
    message = f"You have been invited by {invitation.invited_by.username} to join the family group '{invitation.family_group.name}'.\nClick the link to accept: {invite_url}"
    
    # Log the email details
    logger.info(f"Sending Invite to {invitation.invited_email}: {message}")
    print(f"\n=======================================================")
    print(f"INVITATION TO: {invitation.invited_email}")
    print(f"SUBJECT: {subject}")
    print(f"LINK: {invite_url}")
    print(f"=======================================================\n")
    return True

def get_family_summary(family_group):
    """
    Computes summary/aggregated stats for a family group (member count, admin count, active alerts).
    """
    from .models import FamilyMembership
    # Avoiding circular import for SOSAlert
    from emergency.models import SOSAlert
    
    memberships = FamilyMembership.objects.filter(family_group=family_group, is_approved=True)
    active_alerts = SOSAlert.objects.filter(
        user__family_memberships__family_group=family_group, 
        is_resolved=False
    ).distinct().count()
    
    return {
        "id": family_group.id,
        "name": family_group.name,
        "member_count": memberships.count(),
        "admin_count": memberships.filter(is_admin=True).count(),
        "active_alerts_count": active_alerts
    }
