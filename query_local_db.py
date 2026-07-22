import sqlite3
import os

db_path = "familyconnect/db.sqlite3"
if not os.path.exists(db_path):
    print(f"Database {db_path} does not exist!")
else:
    print(f"Database {db_path} exists. Connecting...")
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    try:
        cur.execute("SELECT id, username, email, is_otp_verified, role FROM users_customuser;")
        rows = cur.fetchall()
        print("Users in database:")
        for r in rows:
            print(r)
    except Exception as e:
        print("Error reading users table:", str(e))
    finally:
        conn.close()
