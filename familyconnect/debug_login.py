import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'familyconnect.settings')
django.setup()

from users.auth_serializers import EmailTokenObtainPairSerializer
from django.contrib.auth import get_user_model

User = get_user_model()

def test_login():
    serializer = EmailTokenObtainPairSerializer()
    data = {
        'username': 'testuser',
        'password': 'Password123'
    }
    try:
        result = serializer.validate(data)
        print("Success:", result)
    except Exception as e:
        import traceback
        print("Error:", str(e))
        traceback.print_exc()

if __name__ == "__main__":
    test_login()
