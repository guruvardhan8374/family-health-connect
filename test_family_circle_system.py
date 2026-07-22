import os
import sys
import json
import uuid

print("=" * 70)
print("  END-TO-END AUDIT & VERIFICATION: FAMILY CIRCLE SYSTEM")
print("=" * 70)

# Setup Django environment
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'familyconnect'))
os.environ['DJANGO_SETTINGS_MODULE'] = 'familyconnect.settings'

import django
django.setup()

from django.test import RequestFactory
from rest_framework.test import force_authenticate
from family.views import FamilyGroupViewSet, FamilyMembershipViewSet
from family.models import FamilyGroup, FamilyMembership
from users.models import CustomUser

factory = RequestFactory()
group_view = FamilyGroupViewSet.as_view({'post': 'create', 'get': 'list'})
join_view = FamilyGroupViewSet.as_view({'post': 'join_by_code'})
membership_view = FamilyMembershipViewSet.as_view({'get': 'list'})

unique_suffix = uuid.uuid4().hex[:6]
username_head = f"head_user_{unique_suffix}"
username_member = f"member_user_{unique_suffix}"

# ── 1. REGISTER USERS ──────────────────────────────────────────────────────
print(f"\n--- 1. Registering Head User ({username_head}) & Member User ({username_member}) ---")
head_user = CustomUser.objects.create_user(
    username=username_head,
    email=f"{username_head}@example.com",
    password="Password@123",
    role="HEAD"
)
member_user = CustomUser.objects.create_user(
    username=username_member,
    email=f"{username_member}@example.com",
    password="Password@123",
    role="MEMBER"
)
print("--> Users registered in database successfully.")

# ── 2. LOGIN HEAD USER & CREATE FAMILY CIRCLE ─────────────────────────────
print(f"\n--- 2. Head User Creating Family Circle ---")
create_payload = {
    "name": f"Circle {unique_suffix}",
    "description": "Automated End-to-End Test Circle"
}
req_create = factory.post(
    '/api/v1/family/groups/',
    data=json.dumps(create_payload),
    content_type='application/json'
)
force_authenticate(req_create, user=head_user)
res_create = group_view(req_create)

print(f"HTTP Status: {res_create.status_code}")
assert res_create.status_code == 201
family_code = res_create.data['family_code']
group_id = res_create.data['id']
print(f"--> Circle Created: ID={group_id}, Code='{family_code}'")

# ── 3. VERIFY PERSISTENCE & HEAD MEMBERSHIP ────────────────────────────────
print("\n--- 3. Verifying Database Storage & Membership Persistence ---")
db_group = FamilyGroup.objects.get(id=group_id)
db_head_mem = FamilyMembership.objects.filter(user=head_user, family_group=db_group).first()

assert db_head_mem is not None
assert db_head_mem.is_admin == True
assert db_head_mem.is_approved == True
assert db_head_mem.status == 'ACTIVE'
print("--> Head Membership correctly saved as ACTIVE & ADMIN.")

# ── 4. RE-LOGIN HEAD USER (SIMULATING RESTART/LOGOUT) ─────────────────────
print("\n--- 4. Re-logging Head User & Fetching Family Groups ---")
req_relist = factory.get('/api/v1/family/groups/')
force_authenticate(req_relist, user=head_user)
res_relist = group_view(req_relist)

assert res_relist.status_code == 200
user_groups = res_relist.data
assert any(g['id'] == group_id for g in user_groups)
print(f"--> Head User automatically restored Family Circle. Count={len(user_groups)}")

# ── 5. SECOND USER JOINS VIA FAMILY CODE ──────────────────────────────────
print(f"\n--- 5. Member User ({username_member}) Joining via Code '{family_code}' ---")
join_payload = {
    "family_code": family_code.lower(), # test case-insensitive code match
    "label": "CHILD"
}
req_join = factory.post(
    '/api/v1/family/groups/join-by-code/',
    data=json.dumps(join_payload),
    content_type='application/json'
)
force_authenticate(req_join, user=member_user)
res_join = join_view(req_join)

print(f"HTTP Status: {res_join.status_code}")
print(f"Response   : {res_join.data}")
assert res_join.status_code in [200, 201]

# ── 6. VERIFY MEMBER USER AUTOMATIC CIRCLE RESTORATION ─────────────────────
print("\n--- 6. Re-logging Member User & Confirming Circle Auto-Detection ---")
req_mem_groups = factory.get('/api/v1/family/groups/')
force_authenticate(req_mem_groups, user=member_user)
res_mem_groups = group_view(req_mem_groups)

assert res_mem_groups.status_code == 200
member_groups = res_mem_groups.data
print(f"Member Groups Found: {len(member_groups)}")
assert any(g['id'] == group_id for g in member_groups)
print("--> Member User automatically restored Family Circle after login!")

# ── 7. VERIFY FAMILY MEMBERSHIP DIRECTORY LIST FOR BOTH USERS ─────────────
print("\n--- 7. Verifying Family Directory Member Count ---")
req_dir = factory.get('/api/v1/family/members/')
force_authenticate(req_dir, user=head_user)
res_dir = membership_view(req_dir)

group_mems = [m for m in res_dir.data if m['family_group'] == group_id]
print(f"Total Active Members in Circle: {len(group_mems)}")
assert len(group_mems) == 2
print("--> Both Head User and Member User are visible in the Family Circle Directory.")

print("\n======================================================================")
print("  ALL E2E FAMILY CIRCLE TESTS PASSED SUCCESSFULLY! - PASS")
print("======================================================================")
