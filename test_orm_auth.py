import os
import sys

# Change directory to familyconnect
sys.path.insert(0, os.path.abspath('familyconnect'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'familyconnect.settings')

import django
django.setup()

from users.models import CustomUser

print("--- Testing Django ORM User Lookup ---")
try:
    user = CustomUser.objects.get(username__iexact='guru')
    print("Found user:", user.username, "| Email:", user.email, "| Verified:", user.is_otp_verified)
    print("Checking password 'Guru@8374':", user.check_password('Guru@8374'))
except CustomUser.DoesNotExist:
    print("User 'guru' does NOT exist in Django's active database!")
except Exception as e:
    print("Error during lookup:", str(e))
