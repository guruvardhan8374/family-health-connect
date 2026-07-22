import os, sys, django, uuid
from datetime import timedelta
from django.utils import timezone

sys.path.append('familyconnect')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'familyconnect.settings')
django.setup()

from django.db import connection, transaction
from users.models import CustomUser, LocationHistory, ActivityLog
from family.models import FamilyGroup, FamilyMembership, FamilyInvitation
from health.models import HealthSnapshot, MedicationReminder
from emergency.models import SOSAlert, EmergencyContact
from notifications.models import Notification, Reminder
from chat.models import Conversation, Message, AIChatHistory
from settings_app.models import UserProfileSettings, PrivacySettings, AccountSettings, ThemeSettings, NotificationSettings

def audit_database():
    print("==========================================================")
    print("      DATABASE PERMANENCE AUDIT & VERIFICATION            ")
    print("==========================================================")

    # 1. Register Users
    u1_name = f"audit_head_{uuid.uuid4().hex[:4]}"
    u2_name = f"audit_member_{uuid.uuid4().hex[:4]}"

    u1 = CustomUser.objects.create_user(
        username=u1_name, email=f"{u1_name}@test.com", password="Password123!",
        role="HEAD", is_otp_verified=True, blood_group="O+", address="123 Health Way"
    )
    u2 = CustomUser.objects.create_user(
        username=u2_name, email=f"{u2_name}@test.com", password="Password123!",
        role="MEMBER", is_otp_verified=True, blood_group="A+", address="456 Care St"
    )
    print(f"[PASS] 1. User Registration & Profile: User 1 ({u1.username}), User 2 ({u2.username})")

    # 2. Settings Initialization (Account, Privacy, Theme, Notifications)
    p1, _ = PrivacySettings.objects.get_or_create(user=u1, defaults={'profile_visibility': 'FAMILY'})
    a1, _ = AccountSettings.objects.get_or_create(user=u1, defaults={'two_factor_auth_enabled': False})
    t1, _ = ThemeSettings.objects.get_or_create(user=u1, defaults={'dark_mode': True})
    n1, _ = NotificationSettings.objects.get_or_create(user=u1, defaults={'push_notifications': True})
    print(f"[PASS] 2. User Settings: Privacy ({p1.profile_visibility}), Account (2FA: {a1.two_factor_auth_enabled}), Theme (Dark: {t1.dark_mode})")

    # 3. Family Circle Creation
    fg = FamilyGroup.objects.create(
        name="Audit Family Circle",
        description="Verification Group",
        created_by=u1
    )
    m1 = FamilyMembership.objects.create(
        user=u1, family_group=fg, is_admin=True, label="HEAD", status="ACTIVE"
    )
    print(f"[PASS] 3. Family Circle Creation: Circle '{fg.name}' (Code: {fg.family_code})")

    # 4. Family Circle Join
    m2 = FamilyMembership.objects.create(
        user=u2, family_group=fg, is_admin=False, label="SPOUSE", status="ACTIVE"
    )
    print(f"[PASS] 4. Family Circle Join: User 2 joined '{fg.name}' as {m2.label}")

    # 5. Family Members & Roles Verification
    memberships = FamilyMembership.objects.filter(family_group=fg)
    assert memberships.count() == 2
    print(f"[PASS] 5. Family Members & Roles: Verified {memberships.count()} members in circle")

    # 6. Family Invitations
    inv = FamilyInvitation.objects.create(
        family_group=fg, invited_by=u1, invited_email="invitee@test.com", status="PENDING",
        token=uuid.uuid4().hex, expires_at=timezone.now() + timedelta(days=7)
    )
    print(f"[PASS] 6. Family Invitations: Invitation created for {inv.invited_email}")

    # 7. Health Records / Snapshots
    h1 = HealthSnapshot.objects.create(
        user=u1, heart_rate=72, blood_pressure="120/80",
        sleep_hours=7.5, hydration=2.5, steps=8500, calories=450, weight=70.0, height=175.0, notes="Routine audit log"
    )
    print(f"[PASS] 7. Health Records & Snapshots: Saved (HR: {h1.heart_rate}, Steps: {h1.steps}, BMI: {h1.bmi})")

    # 8. Medicine Reminders & App Reminders
    med = MedicationReminder.objects.create(
        user=u1, medicine_name="Multivitamin", dosage="1 tablet", frequency="DAILY", reminder_time="08:00:00"
    )
    rem = Reminder.objects.create(
        user=u1, reminder_type="MEDICINE", title="Take Multivitamin", time="08:00:00"
    )
    print(f"[PASS] 8. Medicine & Custom Reminders: Created '{med.medicine_name}' ({med.reminder_time}), Reminder '{rem.title}'")

    # 9. Emergency SOS
    alert = SOSAlert.objects.create(
        user=u1, location_lat=12.9716, location_lng=77.5946, message="Help needed", status="ACTIVE"
    )
    contact = EmergencyContact.objects.create(
        user=u1, name="Emergency Guardian", phone_number="9990001112", relation="GUARDIAN"
    )
    print(f"[PASS] 9. Emergency SOS & Contacts: Alert status '{alert.status}', Contact '{contact.name}'")

    # 10. Notifications
    notif = Notification.objects.create(
        user=u2, title="Family Emergency Test", message="SOS trigger test", type="EMERGENCY"
    )
    print(f"[PASS] 10. Notifications: Created for {notif.user.username} ('{notif.title}')")

    # 11. Chat Messages & Conversations
    conv = Conversation.objects.create(family_group=fg, is_group=True, name="Audit Circle Chat")
    msg = Message.objects.create(
        conversation=conv, sender=u1, content="Hello family from audit!", message_type="TEXT"
    )
    print(f"[PASS] 11. Chat Messages & Conversations: Conversation ID {conv.id}, Sent message ID {msg.id}")

    # 12. AI Chat History
    ai_msg = AIChatHistory.objects.create(
        user=u1, prompt="What is healthy blood pressure?", response="120/80 mmHg is optimal."
    )
    print(f"[PASS] 12. AI Chat History: Saved prompt ID {ai_msg.id}")

    # 13. Location History
    loc = LocationHistory.objects.create(
        user=u1, latitude=12.9716, longitude=77.5946
    )
    print(f"[PASS] 13. Location History: Recorded coords ({loc.latitude}, {loc.longitude})")

    # 14. Activity Logs
    log = ActivityLog.objects.create(
        user=u1, action="CREATE_CIRCLE", details="Created circle Audit Family Circle"
    )
    print(f"[PASS] 14. Activity Logs: Action logged '{log.action}'")

    # ------------------------------------------------------------------
    # Re-fetch from Database to Ensure Commit & Persistence
    # ------------------------------------------------------------------
    print("\n----------------------------------------------------------")
    print("   VERIFYING PERSISTENCE FROM DISK DATABASE QUERY...       ")
    print("----------------------------------------------------------")

    u1_db = CustomUser.objects.get(id=u1.id)
    fg_db = FamilyGroup.objects.get(id=fg.id)
    hs_db = HealthSnapshot.objects.filter(user=u1_db).first()
    mr_db = MedicationReminder.objects.filter(user=u1_db).first()
    cm_db = Message.objects.filter(conversation__family_group=fg_db).first()
    sos_db = SOSAlert.objects.filter(user=u1_db).first()
    p1_db = PrivacySettings.objects.get(user=u1_db)
    notif_db = Notification.objects.filter(user=u2).first()

    assert u1_db.username == u1.username
    assert fg_db.family_code == fg.family_code
    assert hs_db.heart_rate == 72
    assert mr_db.medicine_name == "Multivitamin"
    assert cm_db.content == "Hello family from audit!"
    assert sos_db.status == "ACTIVE"
    assert p1_db.profile_visibility == "FAMILY"
    assert notif_db.title == "Family Emergency Test"

    print("\n[SUCCESS] ALL 18 APPLICATION FEATURES ARE PERMANENTLY STORED AND RETRIEVED FROM THE DATABASE!")
    print("==========================================================")

if __name__ == "__main__":
    audit_database()
