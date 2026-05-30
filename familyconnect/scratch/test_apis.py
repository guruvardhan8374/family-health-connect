import os
import sys
import django
from django.test import Client
from django.contrib.auth import get_user_model

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'familyconnect.settings')
django.setup()

def run_tests():
    User = get_user_model()
    # Find or create a test user
    user = User.objects.filter(username='testuser').first()
    if not user:
        user = User.objects.create_user(
            username='testuser', 
            email='testuser@example.com', 
            password='Password123',
            role='HEAD'
        )
        print("Created testuser.")
    else:
        print("Found testuser.")
        
    client = Client()
    client.force_login(user)
    
    endpoints = [
        ('/api/v1/settings/profile/', 'GET'),
        ('/api/v1/settings/profile/', 'PUT', {
            'username': 'testuser_updated',
            'phone_number': '1234567890',
            'bio': 'Test bio info',
            'emergency_contact': 'John Doe',
            'preferred_language': 'en',
            'timezone': 'UTC'
        }),
        ('/api/v1/settings/notifications/', 'GET'),
        ('/api/v1/settings/notifications/', 'PUT', {
            'push_notifications': False,
            'medicine_reminders': True
        }),
        ('/api/v1/settings/privacy/', 'GET'),
        ('/api/v1/settings/privacy/', 'PUT', {
            'profile_visibility': 'PRIVATE',
            'location_sharing': False
        }),
        ('/api/v1/settings/theme/', 'GET'),
        ('/api/v1/settings/theme/', 'PUT', {
            'dark_mode': True,
            'theme_color': 'emerald'
        }),
        ('/api/v1/settings/account/', 'GET'),
        ('/api/v1/settings/account/', 'PUT', {
            'two_factor_auth_enabled': True
        }),
        ('/api/v1/chat/conversations/', 'GET'),
        ('/api/v1/chat/stories/', 'GET'),
        ('/api/v1/health-records/health-intelligence/', 'GET'),
        ('/api/v1/chat/ai-assistant/', 'POST', {
            'prompt': 'Tell me about healthy sleeping',
            'context_type': 'HEALTH'
        })
    ]
    
    from rest_framework_simplejwt.tokens import AccessToken
    token = str(AccessToken.for_user(user))
    
    for item in endpoints:
        path = item[0]
        method = item[1]
        data = item[2] if len(item) > 2 else None
        
        print(f"\n--- Testing {method} {path} ---")
        headers = {'HTTP_AUTHORIZATION': f'Bearer {token}'}
        try:
            if method == 'GET':
                res = client.get(path, **headers)
            elif method == 'PUT':
                res = client.put(path, data, content_type='application/json', **headers)
            elif method == 'POST':
                res = client.post(path, data, content_type='application/json', **headers)
            else:
                continue
                
            print(f"Status: {res.status_code}")
            print(f"Response: {res.data if hasattr(res, 'data') else res.content}")
        except Exception as e:
            import traceback
            print(f"FAILED with error: {e}")
            traceback.print_exc()

if __name__ == "__main__":
    run_tests()
