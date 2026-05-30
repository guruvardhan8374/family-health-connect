import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'familyconnect.settings')
django.setup()

from users.auth_serializers import EmailTokenObtainPairSerializer
from django.contrib.auth import get_user_model

User = get_user_model()
serializer = EmailTokenObtainPairSerializer(data={'username': 'test@example.com', 'password': 'password123'})

try:
    if serializer.is_valid():
        print("Serializer is VALID")
        print("Username resolved to:", serializer.validated_data)
    else:
        print("Serializer INVALID:", serializer.errors)
except Exception as e:
    print("Error during validation:", str(e))
