import os
import sys
import json

print("=" * 60)
print("  TESTING CREATE FAMILY GROUP ENDPOINT (/api/v1/family/groups/)")
print("=" * 60)

# Setup Django environment
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'familyconnect'))
os.environ['DJANGO_SETTINGS_MODULE'] = 'familyconnect.settings'

import django
django.setup()

from django.test import RequestFactory
from family.views import FamilyGroupViewSet, FamilyMembershipViewSet
from family.models import FamilyGroup, FamilyMembership
from users.models import CustomUser

factory = RequestFactory()
group_view = FamilyGroupViewSet.as_view({'post': 'create', 'get': 'list'})
membership_view = FamilyMembershipViewSet.as_view({'get': 'list'})

user = CustomUser.objects.get(username='guru')

# ── 1. TEST POST /api/v1/family/groups/ (Create Group) ───────────────────
print("\n--- 1. Testing POST /api/v1/family/groups/ ---")
payload = {
    "name": "Test Guru Family Circle",
    "description": "Created via automated test suite"
}

from rest_framework.test import force_authenticate

req_create = factory.post(
    '/api/v1/family/groups/',
    data=json.dumps(payload),
    content_type='application/json'
)
force_authenticate(req_create, user=user)

res_create = group_view(req_create)
print(f"Status Code: {res_create.status_code}")
print(f"Response   : {res_create.data}")

assert res_create.status_code == 201
group_id = res_create.data['id']
family_code = res_create.data['family_code']

# ── 2. VERIFY DATABASE OPERATIONAL DATA ────────────────────────────────────
print("\n--- 2. Verifying Database Storage & HEAD Membership ---")
group_db = FamilyGroup.objects.get(id=group_id)
print(f"DB Group Name : {group_db.name}")
print(f"Family Code   : {group_db.family_code}")
print(f"Created By    : {group_db.created_by.username}")

membership_db = FamilyMembership.objects.filter(user=user, family_group=group_db).first()
assert membership_db is not None
print(f"Membership Found: is_admin={membership_db.is_admin}, is_approved={membership_db.is_approved}, label={membership_db.label}, status={membership_db.status}")

assert membership_db.is_admin == True
assert membership_db.is_approved == True
assert membership_db.label == 'HEAD'

# ── 3. VERIFY GET LIST (FOR BOTH FLUTTER & REACT) ──────────────────────────
print("\n--- 3. Testing GET /api/v1/family/groups/ & /family/members/ ---")
req_groups_list = factory.get('/api/v1/family/groups/')
force_authenticate(req_groups_list, user=user)
res_groups_list = group_view(req_groups_list)
print(f"Groups List Count: {len(res_groups_list.data)}")
assert any(g['id'] == group_id for g in res_groups_list.data)

req_members_list = factory.get('/api/v1/family/members/')
force_authenticate(req_members_list, user=user)
res_members_list = membership_view(req_members_list)
print(f"Memberships List Count: {len(res_members_list.data)}")
assert any(m['family_group'] == group_id for m in res_members_list.data)

print("\n============================================================")
print("  CREATE FAMILY GROUP TEST PASSED SUCCESSFULLY! - PASS")
print("============================================================")
