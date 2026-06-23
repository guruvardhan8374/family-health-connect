import os
import sys
import django

# Add parent directory of 'familyconnect' to sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'familyconnect.settings')
django.setup()

from django.contrib.auth import get_user_model
from family.models import FamilyGroup, FamilyMembership
from family.views import generate_family_code

User = get_user_model()
user = User.objects.first()

if not user:
    print("No users found in database to test with.")
else:
    print(f"Testing with user: {user.username}")
    try:
        code = generate_family_code()
        print(f"Generated family code: {code}")
        group = FamilyGroup.objects.create(
            name="Test Family Circle",
            description="Testing creation",
            family_code=code,
            created_by=user
        )
        print(f"Created group: {group}")
        membership = FamilyMembership.objects.create(
            user=user,
            family_group=group,
            is_admin=True,
            is_approved=True,
            label='PARENT'
        )
        print(f"Created membership: {membership}")
    except Exception as e:
        import traceback
        traceback.print_exc()
