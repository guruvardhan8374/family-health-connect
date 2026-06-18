import requests
import json

url = "https://familyhealthbackend.loca.lt/api/token/"
headers = {
    "Content-Type": "application/json",
    "Bypass-Tunnel-Reminder": "true"
}
data = {
    "username": "user1",
    "password": "Pass@123"
}
response = requests.post(url, headers=headers, json=data)
print(f"Status Code: {response.status_code}")
print(f"Response: {response.text}")
