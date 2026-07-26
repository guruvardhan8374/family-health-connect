import os
import sys
import uuid

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'familyconnect.settings')
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'familyconnect'))

import django
django.setup()

from rest_framework.test import APIClient
from users.models import CustomUser, LocationHistory
from family.models import FamilyGroup, FamilyMembership
from settings_app.models import PrivacySettings

def run_test():
    print("=" * 70)
    print("  E2E TEST: REAL-TIME FAMILY LOCATION SHARING & LAST KNOWN LOCATION")
    print("=" * 70)

    uid = uuid.uuid4().hex[:6]
    user1 = CustomUser.objects.create_user(username=f'loc_head_{uid}', email=f'loc_head_{uid}@example.com', password='password123')
    user2 = CustomUser.objects.create_user(username=f'loc_mem_{uid}', email=f'loc_mem_{uid}@example.com', password='password123')

    # Create Family Group
    group = FamilyGroup.objects.create(name=f"Location Circle {uid}", created_by=user1, family_code=f"LOC{uid.upper()}")
    FamilyMembership.objects.create(user=user1, family_group=group, is_admin=True, is_approved=True)
    FamilyMembership.objects.create(user=user2, family_group=group, is_admin=False, is_approved=True)

    client1 = APIClient()
    client1.force_authenticate(user=user1)

    client2 = APIClient()
    client2.force_authenticate(user=user2)

    print("\n--- 1. Sending Live Location Update from User 1 ---")
    res1 = client1.post('/api/v1/locations/', {
        'latitude': 12.9716,
        'longitude': 77.5946,
        'speed': 25.4,
        'battery_level': 88,
        'is_moving': True
    }, format='json')
    assert res1.status_code == 201, f"Expected 201, got {res1.status_code}: {res1.data}"
    print(f"--> Location saved: lat={res1.data['latitude']}, lng={res1.data['longitude']}, speed={res1.data['speed']}, battery={res1.data['battery_level']}")

    print("\n--- 2. User 2 Fetching Family Members (Verifying Live Online Status) ---")
    res2 = client2.get('/api/v1/family/members/')
    assert res2.status_code == 200
    members = res2.data if isinstance(res2.data, list) else res2.data.get('results', [])

    u1_member = next(m for m in members if m['user'] == user1.id)
    latest = u1_member['latest_location']
    assert latest is not None, "latest_location should not be None"
    assert latest['latitude'] == 12.9716
    assert latest['longitude'] == 77.5946
    assert latest['speed'] == 25.4
    assert latest['battery_level'] == 88
    assert latest['is_online'] == True
    assert latest['is_sharing_enabled'] == True
    assert latest['last_seen_formatted'] == 'Just now'
    print(f"--> User 2 successfully sees User 1's Live Location! (is_online={latest['is_online']}, speed={latest['speed']}km/h, battery={latest['battery_level']}%)")

    print("\n--- 3. User 1 Disabling Location Sharing in PrivacySettings ---")
    privacy, _ = PrivacySettings.objects.get_or_create(user=user1)
    privacy.location_sharing = False
    privacy.save()

    res3 = client2.get('/api/v1/family/members/')
    u1_member_disabled = next(m for m in res3.data if m['user'] == user1.id)
    latest_disabled = u1_member_disabled['latest_location']
    assert latest_disabled['is_sharing_enabled'] == False
    assert latest_disabled['is_online'] == False
    assert latest_disabled['is_last_known'] == True
    print(f"--> User 2 correctly sees User 1 with Sharing Disabled & Last Known Location (is_sharing_enabled={latest_disabled['is_sharing_enabled']}, is_last_known={latest_disabled['is_last_known']})")

    print("\n--- 4. Re-enabling Location Sharing & Verification ---")
    privacy.location_sharing = True
    privacy.save()

    res4 = client2.get('/api/v1/family/members/')
    u1_member_reenabled = next(m for m in res4.data if m['user'] == user1.id)
    assert u1_member_reenabled['latest_location']['is_sharing_enabled'] == True
    print("--> Live location sharing successfully re-enabled!")

    print("\n" + "=" * 70)
    print("  ALL E2E LOCATION SHARING TESTS PASSED SUCCESSFULLY! - PASS")
    print("=" * 70)

if __name__ == '__main__':
    run_test()
