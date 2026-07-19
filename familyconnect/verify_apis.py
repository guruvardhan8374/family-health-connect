import requests
import json
import time

base_url = "http://127.0.0.1:8000"

def test_flow():
    timestamp = int(time.time())
    username = f"api_user_{timestamp}"
    email = f"api_email_{timestamp}@example.com"
    
    # 1. Register a new user
    reg_url = f"{base_url}/api/v1/users/register/"
    reg_payload = {
        "username": username,
        "email": email,
        "password": "ApiTestPassword123!",
        "password_confirm": "ApiTestPassword123!",
        "role": "MEMBER"
    }

    print("--- 1. REGISTERING USER ---")
    response = requests.post(reg_url, json=reg_payload)
    print("Status Code:", response.status_code)
    print("Response JSON:", response.text)
    
    if response.status_code != 201:
        print("Registration failed.")
        return

    # 2. Login
    login_url = f"{base_url}/api/v1/token/"
    login_payload = {
        "username": username,
        "password": "ApiTestPassword123!"
    }
    
    print("\n--- 2. LOGGING IN ---")
    login_resp = requests.post(login_url, json=login_payload)
    print("Status Code:", login_resp.status_code)
    print("Response JSON:", login_resp.text)
    
    if login_resp.status_code != 200:
        print("Login failed.")
        return
        
    token = login_resp.json()["access"]
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    # 3. Create Family Circle
    create_url = f"{base_url}/api/v1/family/groups/"
    create_payload = {
        "name": f"Family Circle {timestamp}",
        "description": "Verification Family Group"
    }
    
    print("\n--- 3. CREATING FAMILY CIRCLE ---")
    create_resp = requests.post(create_url, json=create_payload, headers=headers)
    print("Status Code:", create_resp.status_code)
    print("Response JSON:", create_resp.text)

if __name__ == "__main__":
    test_flow()
