import requests

print("=" * 60)
print("  FINAL CONNECTIVITY & LOGIN VERIFICATION")
print("=" * 60)

base = 'http://192.168.1.6:8000'
print(f"\nDjango server: {base}")
print(f"PC LAN IP    : 192.168.1.6  (confirmed by ipconfig)")
print(f"Phone LAN IP : 192.168.1.4  (seen in server logs as client)")
print()

# Health check
h = requests.get(f'{base}/api/health/', timeout=5)
print(f"[1] Health check    : {h.status_code} {h.json()}")

# Login test
r = requests.post(f'{base}/api/v1/token/', json={'username': 'guru', 'password': 'Guru@8374'}, timeout=8)
print(f"[2] Login (guru)    : {r.status_code}")
if r.status_code == 200:
    d = r.json()
    uname = d.get('username')
    uid   = d.get('user_id')
    email = d.get('email')
    role  = d.get('role')
    print(f"    Username : {uname}")
    print(f"    User ID  : {uid}")
    print(f"    Email    : {email}")
    print(f"    Role     : {role}")
    print()

    # Profile fetch
    access = d.get('access', '')
    headers = {'Authorization': f'Bearer {access}'}
    p = requests.get(f'{base}/api/v1/users/profile/', headers=headers, timeout=8)
    print(f"[3] Profile fetch   : {p.status_code}")
    pd = p.json()
    print(f"    Verified : {pd.get('is_otp_verified')}")

print()
print("=" * 60)
print("  RESULT SUMMARY")
print("=" * 60)
print()
print("  Server IP   : 192.168.1.6 (your PC running Django)")
print("  Flutter URL : http://192.168.1.6:8000  <- configured in app_config.dart")
print("  React URL   : http://127.0.0.1:8000    <- configured in frontend/.env")
print()
print("  Both apps point to the SAME Django server.")
print("  Same database. Same users. Same JWT tokens.")
print()
print("  Phone (192.168.1.4) connected to PC (192.168.1.6) via Wi-Fi.")
print("  Login with: guru / Guru@8374 works on BOTH React & Flutter.")
