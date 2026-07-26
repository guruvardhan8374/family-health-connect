import logging
from django.db import transaction
from django.db.models import Count
from users.models import CustomUser

logger = logging.getLogger(__name__)

def deduplicate_users_by_email(email=None):
    """
    Finds duplicate CustomUser records sharing the same email (case-insensitive)
    and consolidates their FamilyMembership, location history, and profile data
    onto the primary user account (the one with active FamilyMembership or earliest joined date).
    """
    from family.models import FamilyMembership

    if email:
        clean_email = email.strip().lower()
        users_qs = CustomUser.objects.filter(email__iexact=clean_email).order_by('id')
        user_groups = [users_qs] if users_qs.count() > 1 else []
    else:
        # Find all emails appearing more than once
        duplicate_emails = CustomUser.objects.values('email') \
            .annotate(cnt=Count('id')) \
            .filter(cnt__gt=1) \
            .values_list('email', flat=True)
        user_groups = [CustomUser.objects.filter(email__iexact=e).order_by('id') for e in duplicate_emails if e]

    merged_count = 0
    for group in user_groups:
        users = list(group)
        if len(users) <= 1:
            continue

        # Determine primary user:
        # 1. Prefer user with active FamilyMembership
        # 2. Otherwise prefer user with earliest date_joined
        primary_user = None
        for u in users:
            if FamilyMembership.objects.filter(user=u, is_approved=True).exists():
                primary_user = u
                break
        
        if not primary_user:
            primary_user = users[0]

        secondary_users = [u for u in users if u.id != primary_user.id]

        with transaction.atomic():
            for sec in secondary_users:
                logger.info(f"[Deduplicate] Merging user ID {sec.id} ({sec.username}) into Primary User ID {primary_user.id} ({primary_user.username})")
                
                # Transfer FamilyMemberships
                sec_memberships = FamilyMembership.objects.filter(user=sec)
                for mem in sec_memberships:
                    if not FamilyMembership.objects.filter(user=primary_user, family_group=mem.family_group).exists():
                        mem.user = primary_user
                        mem.save(update_fields=['user'])
                    else:
                        mem.delete()

                # Reassign LocationHistory
                sec.location_history.all().update(user=primary_user)

                # Reassign UserSettings if primary has none
                if hasattr(sec, 'settings') and not hasattr(primary_user, 'settings'):
                    sec.settings.user = primary_user
                    sec.settings.save()

                # Ensure primary user is marked verified
                if sec.is_otp_verified and not primary_user.is_otp_verified:
                    primary_user.is_otp_verified = True
                    primary_user.save(update_fields=['is_otp_verified'])

                # Delete secondary orphan user
                sec.delete()
                merged_count += 1

    return merged_count
