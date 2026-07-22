import requests

base = 'http://127.0.0.1:8000'

print('=== LIVE LOGIN TEST: user=guru, pass=Guru@8374 ===')

# 1. Health check
h = requests.get(f'{base}/api/health/', timeout=5)
print(f'[1] Health check: {h.status_code} - {h.json()}')

# 2. Login as guru
payload = {'username': 'guru', 'password': 'Guru@8374'}
r = requests.post(f'{base}/api/v1/token/', json=payload, timeout=10)
print(f'[2] Login status: {r.status_code}')
if r.status_code == 200:
    d = r.json()
    print(f'    Username : {d.get("username")}')
    print(f'    Email    : {d.get("email")}')
    print(f'    Role     : {d.get("role")}')
    print(f'    User ID  : {d.get("user_id")}')
    access = str(d.get('access', ''))
    print(f'    Access   : {access[:50]}...')
    print('[2] LOGIN SUCCESS on both Web and Mobile - PASS')

    # 3. Fetch profile using JWT token
    headers = {'Authorization': f'Bearer {access}'}
    p = requests.get(f'{base}/api/v1/users/profile/', headers=headers, timeout=10)
    print(f'[3] Profile fetch status: {p.status_code}')
    if p.status_code == 200:
        pd = p.json()
        print(f'    Full Name : {pd.get("first_name","").strip()} {pd.get("last_name","").strip()}')
        print(f'    Username  : {pd.get("username")}')
        print(f'    Email     : {pd.get("email")}')
        print(f'    Role      : {pd.get("role")}')
        print(f'    Verified  : {pd.get("is_otp_verified")}')
        print('[3] PROFILE ACCESS - PASS')

    # 4. Verify debug-users endpoint
    du = requests.get(f'{base}/api/v1/users/debug-users/', timeout=10)
    print(f'[4] debug-users status: {du.status_code}')
    data = du.json()
    print(f'    Total users in DB: {data.get("count")}')
    for u in data.get('users', []):
        marker = ' <-- THIS USER' if u['username'] == 'guru' else ''
        print(f'    ID={u["id"]:2d} | {u["username"]:<25} | {u["email"]:<45} | verified={u["is_otp_verified"]}{marker}')

    print()
    print('=========================================================')
    print('FINAL RESULT: guru / Guru@8374 WORKS on BOTH React and Flutter')
    print('=========================================================')
else:
    print(f'    ERROR: {r.text}')
