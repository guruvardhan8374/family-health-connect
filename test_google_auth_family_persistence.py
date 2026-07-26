import os
import sys
import uuid

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'familyconnect.settings')
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'familyconnect'))

import django
django.setup()

from rest_framework.test import APIClient
from users.models import CustomUser
from family.models import FamilyGroup, FamilyMembership
from users.utils import deduplicate_users_by_email

def run_test():
    print("=" * 75)
    print("  VERIFICATION TEST: GOOGLE AUTH & FAMILY CIRCLE PERSISTENCE SUITE")
    print("=" * 75)

    uid = uuid.uuid4().hex[:6]
    email_mixed_case = f"Test.Google.User_{uid}@Example.Com"
    email_lower = email_mixed_case.lower()
    client = APIClient()

    print(f"\n--- 1. Initial Google Sign-In with Mixed-Case Email: {email_mixed_case} ---")
    res1 = client.post('/api/v1/users/google-login/', {
        'email': email_mixed_case,
        'username': f'google_user_{uid}',
        'id_token': 'mock_google_id_token_123'
    })
    assert res1.status_code == 200, f"Expected 200, got {res1.status_code}: {res1.data}"
    user_id_1 = res1.data['user_id']
    token_1 = res1.data['access']
    refresh_1 = res1.data['refresh']
    print(f"--> Google Auth successful! User ID: {user_id_1}, Email: {res1.data['email']}")
    assert res1.data['has_family'] == False, "New user should not have family initially"

    print("\n--- 2. Creating Family Circle for User ---")
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {token_1}')
    res_fam = client.post('/api/v1/family/groups/', {
        'name': f'Emerald Family {uid}',
        'description': 'Family circle created via Google login'
    })
    assert res_fam.status_code == 201, f"Expected 201, got {res_fam.status_code}: {res_fam.data}"
    family_id = res_fam.data['id']
    family_code = res_fam.data['family_code']
    print(f"--> Family Circle created! Group ID: {family_id}, Code: {family_code}")

    print("\n--- 3. Logging Out (Clearing Credentials) ---")
    client.credentials()

    print(f"\n--- 4. Logging In Again via Google using Lowercase Email: {email_lower} ---")
    res2 = client.post('/api/v1/users/google-login/', {
        'email': email_lower,
        'username': f'google_user_{uid}',
        'id_token': 'mock_google_id_token_123'
    })
    assert res2.status_code == 200, f"Expected 200, got {res2.status_code}: {res2.data}"
    user_id_2 = res2.data['user_id']
    print(f"--> Google Auth re-login successful! Returned User ID: {user_id_2}")

    print("\n--- 5. Verifying User Identity & No Duplicate Accounts ---")
    assert user_id_1 == user_id_2, f"FAIL: Expected same User ID {user_id_1}, but got {user_id_2}"
    dup_count = CustomUser.objects.filter(email__iexact=email_lower).count()
    assert dup_count == 1, f"FAIL: Expected 1 user record, found {dup_count} duplicate users in database!"
    print(f"--> Identity mapping verified! Exact 1 user record in database for {email_lower} - PASS")

    print("\n--- 6. Verifying Family Circle Restoration in Login Payload ---")
    assert res2.data['has_family'] == True, "FAIL: has_family should be True after re-login!"
    assert res2.data['family_group']['family_id'] == family_id, "FAIL: Incorrect family_id returned"
    print(f"--> Family Circle restored in login payload: '{res2.data['family_group']['family_name']}' ({family_code}) - PASS")

    print("\n--- 7. Verifying Profile & Family Group Endpoints ---")
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {res2.data["access"]}')
    res_prof = client.get('/api/v1/users/profile/')
    assert res_prof.status_code == 200
    assert res_prof.data['has_family'] == True
    print("--> /users/profile/ response contains active family group details - PASS")

    res_groups = client.get('/api/v1/family/groups/')
    assert res_groups.status_code == 200
    groups_list = res_groups.data if isinstance(res_groups.data, list) else res_groups.data.get('results', [])
    assert len(groups_list) >= 1
    assert groups_list[0]['id'] == family_id
    print(f"--> /family/groups/ returned {len(groups_list)} group(s) including active Family Circle - PASS")

    print("\n--- 8. Verifying JWT Token Refresh ---")
    res_ref = client.post('/api/v1/token/refresh/', {'refresh': refresh_1})
    assert res_ref.status_code == 200 and 'access' in res_ref.data
    print("--> JWT token refresh successful - PASS")

    print("\n--- 9. Testing Database Deduplication Engine ---")
    # Simulate orphan user record with duplicate email
    orphan_user = CustomUser.objects.create_user(
        username=f'orphan_{uid}',
        email=email_mixed_case.upper(),
        password='password123'
    )
    assert CustomUser.objects.filter(email__iexact=email_lower).count() == 2
    merged = deduplicate_users_by_email(email_lower)
    assert merged == 1
    assert CustomUser.objects.filter(email__iexact=email_lower).count() == 1
    print("--> Database deduplication engine successfully merged orphan user account - PASS")

    print("\n" + "=" * 75)
    print("  ALL GOOGLE AUTH & FAMILY CIRCLE PERSISTENCE TESTS PASSED! - PASS")
    print("=" * 75)

if __name__ == '__main__':
    run_test()
