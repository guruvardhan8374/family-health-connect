import requests

base = 'http://192.168.1.4:8000'
print('Testing Django backend at', base)
try:
    h = requests.get(f'{base}/api/health/', timeout=4)
    print(f'[1] Health check: {h.status_code} - {h.json()}')

    r = requests.post(f'{base}/api/v1/token/', json={'username': 'guru', 'password': 'Guru@8374'}, timeout=6)
    print(f'[2] Login (guru): {r.status_code}')
    if r.status_code == 200:
        d = r.json()
        uname = d.get('username')
        uid   = d.get('user_id')
        email = d.get('email')
        print(f'    Username : {uname}')
        print(f'    User ID  : {uid}')
        print(f'    Email    : {email}')
        print()
        print('SUCCESS: Flutter app pointing at 192.168.1.4:8000 will work correctly')
    else:
        print(f'  Error: {r.text}')
except Exception as e:
    print(f'FAILED: {e}')
    print('The Django server is not running. Start it with:')
    print('.\\venv\\Scripts\\python.exe familyconnect\\manage.py runserver 0.0.0.0:8000')
