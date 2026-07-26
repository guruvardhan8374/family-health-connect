import urllib.request
import urllib.error
import json
import sys
import io
import pymysql
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

base = "http://127.0.0.1:8000"

print("=" * 60)
print("FULL SYSTEM VERIFICATION - Family Health Connect")
print("=" * 60)

def post(url, payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode())
    except Exception as ex:
        return 0, {"error": str(ex)}

# ── A: Direct MySQL connection check ─────────────────────────────────────────
print("\n[A] MySQL Connection Check (XAMPP)")
try:
    conn = pymysql.connect(host='127.0.0.1', port=3306, user='root', password='', database='family_health_connect')
    c = conn.cursor()
    c.execute("SELECT COUNT(*) FROM users_customuser")
    total = c.fetchone()[0]
    print(f"    CONNECTED! Total users in MySQL: {total}")
    c.execute("SELECT id, username, email, is_active FROM users_customuser ORDER BY id")
    for r in c.fetchall():
        print(f"      - ID={r[0]} | {r[1]} | {r[2]} | active={r[3]}")
    conn.close()
except Exception as ex:
    print(f"    MYSQL ERROR: {ex}")

# ── B: Register a brand new test user ────────────────────────────────────────
print("\n[B] Registering new test user via API (password_confirm field)")
status, body = post(f"{base}/api/v1/users/register/", {
    "username": "testcross",
    "email": "testcross@example.com",
    "password": "Cross@12345",
    "password_confirm": "Cross@12345",
    "role": "MEMBER"
})
print(f"    Status: {status}")
if status in [200, 201]:
    print(f"    REGISTRATION SUCCESS!")
else:
    print(f"    Result: {body}")

# ── C: Verify user appeared in MySQL ─────────────────────────────────────────
print("\n[C] Verifying new user exists in MySQL")
try:
    conn = pymysql.connect(host='127.0.0.1', port=3306, user='root', password='', database='family_health_connect')
    c = conn.cursor()
    c.execute("SELECT id, username, email, is_active, is_otp_verified FROM users_customuser WHERE username='testcross'")
    row = c.fetchone()
    if row:
        print(f"    USER EXISTS IN MYSQL! ID={row[0]} | {row[1]} | {row[2]} | active={row[3]} | otp_verified={row[4]}")
    else:
        print(f"    NOT FOUND IN MYSQL!")
    conn.close()
except Exception as ex:
    print(f"    MYSQL ERROR: {ex}")

# ── D: Cross-platform login (simulate React or Flutter) ──────────────────────
print("\n[D] Cross-platform login test (same user, either platform)")
status2, body2 = post(f"{base}/api/v1/token/", {"username": "testcross", "password": "Cross@12345"})
print(f"    Status: {status2}")
if status2 == 200:
    print(f"    LOGIN SUCCESS! This user can login from BOTH Flutter and React.")
    print(f"    user_id={body2.get('user_id')} | role={body2.get('role')} | has_family={body2.get('has_family')}")
else:
    print(f"    LOGIN FAILED: {body2}")

# ── E: Verify Django settings point to MySQL (not SQLite) ────────────────────
print("\n[E] Django Database Configuration Check")
try:
    conn = pymysql.connect(host='127.0.0.1', port=3306, user='root', password='', database='family_health_connect')
    c = conn.cursor()
    c.execute("SHOW TABLES")
    tables = [r[0] for r in c.fetchall()]
    print(f"    Tables in MySQL: {len(tables)} tables found")
    key_tables = ['users_customuser', 'family_familygroup', 'chat_message', 'health_healthmetric', 'emergency_sosalert']
    for t in key_tables:
        status_t = "PRESENT" if t in tables else "MISSING"
        print(f"      - {t}: {status_t}")
    conn.close()
except Exception as ex:
    print(f"    MYSQL ERROR: {ex}")

# ── Cleanup ───────────────────────────────────────────────────────────────────
print("\n[Cleanup] Removing test user")
try:
    conn = pymysql.connect(host='127.0.0.1', port=3306, user='root', password='', database='family_health_connect')
    c = conn.cursor()
    c.execute("DELETE FROM users_customuser WHERE username='testcross'")
    conn.commit()
    conn.close()
    print("    testcross deleted from MySQL")
except Exception as ex:
    print(f"    Cleanup error: {ex}")

print("\n" + "=" * 60)
print("VERIFICATION COMPLETE")
print("=" * 60)
