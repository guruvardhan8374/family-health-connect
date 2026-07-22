import os
import sys

sys.path.insert(0, os.path.abspath('familyconnect'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'familyconnect.settings')

import django
django.setup()

from users.auth_serializers import EmailTokenObtainPairSerializer

print("--- Testing EmailTokenObtainPairSerializer ---")
serializer = EmailTokenObtainPairSerializer(data={'username': 'guru', 'password': 'Guru@8374'})
if serializer.is_valid():
    print("Serializer Valid! Output keys:", list(serializer.validated_data.keys()))
    print("User ID:", serializer.validated_data.get('user_id'))
    print("Username:", serializer.validated_data.get('username'))
else:
    print("Serializer Errors:", serializer.errors)
