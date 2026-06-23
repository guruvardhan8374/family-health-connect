import requests

url = "https://family-health-connect-backend.onrender.com/api/v1/users/debug-db/"
try:
    r = requests.get(url, timeout=30)
    print("Status:", r.status_code)
    print(r.text)
except Exception as e:
    print("Error connecting to Render backend:", str(e))
