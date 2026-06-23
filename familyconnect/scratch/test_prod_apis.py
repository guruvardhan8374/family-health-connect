import requests
import random
import string
import json

# Production backend URL
BASE_URL = "https://family-health-connect-backend.onrender.com"

def get_random_string(length=6):
    letters = string.ascii_lowercase
    return ''.join(random.choice(letters) for i in range(length))

def run_test():
    rand = get_random_string()
    username = f"geminiprod_{rand}"
    email = f"geminiprod_{rand}@example.com"
    password = "SecurePass998!!"
    phone_number = f"+1555{random.randint(1000000, 9999999)}"

    print(f"--- 1. Registering user {username} ({email}) ---")
    reg_url = f"{BASE_URL}/api/v1/users/register/"
    reg_data = {
        "username": username,
        "email": email,
        "password": password,
        "password_confirm": password,
        "phone_number": phone_number,
        "role": "HEAD"
    }
    r = requests.post(reg_url, json=reg_data)
    print(f"Status: {r.status_code}")
    print(r.text)
    if r.status_code != 201:
        print("Registration failed.")
        return

    print(f"\n--- 2. Verifying OTP ---")
    verify_url = f"{BASE_URL}/api/v1/users/verify-otp/"
    verify_data = {
        "email": email,
        "otp": "123456"
    }
    r = requests.post(verify_url, json=verify_data)
    print(f"Status: {r.status_code}")
    print(r.text)
    if r.status_code != 200:
        print("OTP verification failed.")
        return

    print(f"\n--- 3. Logging in (Obtaining Token) ---")
    login_url = f"{BASE_URL}/api/token/"
    login_data = {
        "username": username,
        "password": password
    }
    r = requests.post(login_url, json=login_data)
    print(f"Status: {r.status_code}")
    print(r.text)
    if r.status_code != 200:
        print("Login failed.")
        return
    
    tokens = r.json()
    access_token = tokens["access"]
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }

    print(f"\n--- 4. Creating Family Circle ---")
    create_circle_url = f"{BASE_URL}/api/v1/family/groups/"
    create_data = {
        "name": f"Circle of {username}",
        "description": "Testing circle creation on production Render backend"
    }
    r = requests.post(create_circle_url, json=create_data, headers=headers)
    print(f"Status: {r.status_code}")
    print(r.text)
    if r.status_code != 201:
        print("Family Circle creation failed.")
        return

    print(f"\n--- 5. Fetching Family Circles ---")
    list_url = f"{BASE_URL}/api/v1/family/groups/"
    r = requests.get(list_url, headers=headers)
    print(f"Status: {r.status_code}")
    print(r.text)

if __name__ == "__main__":
    run_test()
