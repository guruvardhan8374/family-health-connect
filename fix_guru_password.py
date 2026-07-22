import os
import sys

sys.path.insert(0, os.path.abspath('familyconnect'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'familyconnect.settings')

import django
django.setup()

from users.models import CustomUser

user = CustomUser.objects.get(username__iexact='guru')
print("Password hash in database:", user.password)

# Reset password to Guru@8374 using set_password to guarantee proper hashing
user.set_password('Guru@8374')
user.is_otp_verified = True
user.save()

print("Password updated! Checking check_password('Guru@8374'):", user.check_password('Guru@8374'))
