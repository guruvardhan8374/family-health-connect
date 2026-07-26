import requests

BASE_URL = 'http://127.0.0.1:8000/api/v1'

# Login to get valid JWT token
auth_res = requests.post(f'http://127.0.0.1:8000/api/token/', json={
    'username': 'guru',
    'password': 'password123'
})

print('Auth response:', auth_res.status_code)
token = auth_res.json().get('access')
headers = {'Authorization': f'Bearer {token}'} if token else {}

endpoints = [
    '/users/profile/',
    '/settings/theme/',
    '/family/groups/',
    '/family/members/',
    '/health/summary/today/',
    '/health/summary/?range=daily',
    '/health/records/',
    '/health/snapshots/',
    '/health/family-summary/',
    '/chat/conversations/',
    '/notifications/',
    '/notifications/unread-count/',
]

for ep in endpoints:
    res = requests.get(f'{BASE_URL}{ep}', headers=headers)
    print(f'{ep:<35} -> {res.status_code}')
