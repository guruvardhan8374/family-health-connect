import sqlite3
import pymysql
import sys

print("==========================================================")
print("   SYNCING PREVIOUS FAMILY CIRCLES FROM SQLITE TO MYSQL    ")
print("==========================================================")

s_conn = sqlite3.connect('familyconnect/db.sqlite3')
s_cur = s_conn.cursor()

m_conn = pymysql.connect(
    host='127.0.0.1',
    port=3306,
    user='root',
    password='',
    database='family_health_connect',
    autocommit=True
)
m_cur = m_conn.cursor()

m_cur.execute("SET FOREIGN_KEY_CHECKS=0;")

# 1. Sync Users
print("\n[1] Syncing Users...")
s_cur.execute("SELECT * FROM users_customuser;")
columns = [description[0] for description in s_cur.description]
users = s_cur.fetchall()

m_cur.execute("SELECT id, username FROM users_customuser;")
existing_mysql_users = {row[0]: row[1] for row in m_cur.fetchall()}
existing_mysql_usernames = set(existing_mysql_users.values())

added_users = 0
for user in users:
    u_dict = dict(zip(columns, user))
    u_id = u_dict['id']
    u_name = u_dict['username']
    
    if u_name in existing_mysql_usernames:
        print(f"  - User '{u_name}' already exists in MySQL. Skipping.")
        continue
    
    # Check if ID is free in MySQL
    if u_id in existing_mysql_users:
        # Find next free ID
        m_cur.execute("SELECT MAX(id) FROM users_customuser;")
        max_id = m_cur.fetchone()[0] or 0
        u_dict['id'] = max_id + 1
        
    cols = ", ".join(f"`{c}`" for c in u_dict.keys())
    vals_placeholder = ", ".join(["%s"] * len(u_dict))
    sql = f"INSERT INTO users_customuser ({cols}) VALUES ({vals_placeholder})"
    
    try:
        m_cur.execute(sql, list(u_dict.values()))
        added_users += 1
        print(f"  + Added user '{u_name}' (ID: {u_dict['id']}) to MySQL.")
    except Exception as e:
        print(f"  ! Error inserting user {u_name}: {e}")

print(f"-> Total new users added to MySQL: {added_users}")

# Refresh MySQL User Map
m_cur.execute("SELECT username, id FROM users_customuser;")
username_to_mysql_id = {row[0]: row[1] for row in m_cur.fetchall()}

# Build map of SQLite User ID -> MySQL User ID
s_cur.execute("SELECT id, username FROM users_customuser;")
sqlite_user_id_to_mysql_id = {}
for s_id, s_name in s_cur.fetchall():
    if s_name in username_to_mysql_id:
        sqlite_user_id_to_mysql_id[s_id] = username_to_mysql_id[s_name]

# 2. Sync Family Groups
print("\n[2] Syncing Family Groups...")
s_cur.execute("SELECT * FROM family_familygroup;")
fg_cols = [description[0] for description in s_cur.description]
family_groups = s_cur.fetchall()

m_cur.execute("SELECT id, name, family_code FROM family_familygroup;")
existing_mysql_groups = {row[0]: row[1] for row in m_cur.fetchall()}
existing_mysql_codes = {row[2] for row in m_cur.fetchall() if row[2]}

added_groups = 0
sqlite_group_id_to_mysql_id = {}

for fg in family_groups:
    fg_dict = dict(zip(fg_cols, fg))
    s_fg_id = fg_dict['id']
    fg_name = fg_dict['name']
    fg_code = fg_dict['family_code']
    s_created_by = fg_dict['created_by_id']
    
    # Map created_by user ID
    if s_created_by in sqlite_user_id_to_mysql_id:
        fg_dict['created_by_id'] = sqlite_user_id_to_mysql_id[s_created_by]
    
    # Check if group code already exists in MySQL
    if fg_code and fg_code in existing_mysql_codes:
        m_cur.execute("SELECT id FROM family_familygroup WHERE family_code=%s;", (fg_code,))
        row = m_cur.fetchone()
        if row:
            sqlite_group_id_to_mysql_id[s_fg_id] = row[0]
            print(f"  - Family Group '{fg_name}' (Code: {fg_code}) already in MySQL (ID: {row[0]}).")
            continue
            
    # Free up ID if needed
    if fg_dict['id'] in existing_mysql_groups:
        m_cur.execute("SELECT MAX(id) FROM family_familygroup;")
        max_fg_id = m_cur.fetchone()[0] or 0
        fg_dict['id'] = max_fg_id + 1
        
    cols = ", ".join(f"`{c}`" for c in fg_dict.keys())
    vals_placeholder = ", ".join(["%s"] * len(fg_dict))
    sql = f"INSERT INTO family_familygroup ({cols}) VALUES ({vals_placeholder})"
    
    try:
        m_cur.execute(sql, list(fg_dict.values()))
        new_mysql_id = fg_dict['id']
        sqlite_group_id_to_mysql_id[s_fg_id] = new_mysql_id
        added_groups += 1
        print(f"  + Added Family Group '{fg_name}' (Code: {fg_code}, MySQL ID: {new_mysql_id}).")
    except Exception as e:
        print(f"  ! Error inserting group {fg_name}: {e}")

print(f"-> Total new Family Groups added to MySQL: {added_groups}")

# 3. Sync Family Memberships
print("\n[3] Syncing Family Memberships...")
s_cur.execute("SELECT * FROM family_familymembership;")
m_cols = [description[0] for description in s_cur.description]
memberships = s_cur.fetchall()

added_memberships = 0
for mem in memberships:
    mem_dict = dict(zip(m_cols, mem))
    s_mem_id = mem_dict['id']
    s_user_id = mem_dict['user_id']
    s_fg_id = mem_dict['family_group_id']
    
    m_user_id = sqlite_user_id_to_mysql_id.get(s_user_id)
    m_fg_id = sqlite_group_id_to_mysql_id.get(s_fg_id)
    
    if not m_user_id or not m_fg_id:
        print(f"  ! Skipping membership {s_mem_id}: User or Group mapping missing.")
        continue
        
    mem_dict['user_id'] = m_user_id
    mem_dict['family_group_id'] = m_fg_id
    
    # Check if membership already exists in MySQL
    m_cur.execute(
        "SELECT id FROM family_familymembership WHERE user_id=%s AND family_group_id=%s;",
        (m_user_id, m_fg_id)
    )
    if m_cur.fetchone():
        print(f"  - Membership for user_id={m_user_id} in group_id={m_fg_id} already exists.")
        continue
        
    m_cur.execute("SELECT MAX(id) FROM family_familymembership;")
    max_m_id = m_cur.fetchone()[0] or 0
    mem_dict['id'] = max_m_id + 1
    
    cols = ", ".join(f"`{c}`" for c in mem_dict.keys())
    vals_placeholder = ", ".join(["%s"] * len(mem_dict))
    sql = f"INSERT INTO family_familymembership ({cols}) VALUES ({vals_placeholder})"
    
    try:
        m_cur.execute(sql, list(mem_dict.values()))
        added_memberships += 1
        print(f"  + Added membership: User ID {m_user_id} in Group ID {m_fg_id}.")
    except Exception as e:
        print(f"  ! Error inserting membership: {e}")

print(f"-> Total new Family Memberships added to MySQL: {added_memberships}")

m_cur.execute("SET FOREIGN_KEY_CHECKS=1;")

s_conn.close()
m_conn.close()
print("\n==========================================================")
print("SUCCESSFULLY SYNCED ALL PREVIOUS FAMILY CIRCLES TO MYSQL!")
print("==========================================================")
