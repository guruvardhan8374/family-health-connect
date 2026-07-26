import socket
import subprocess
import sys

import os

target_ip = "192.168.1.4"
adb_path = r"C:\Users\Pravi\AppData\Local\Android\Sdk\platform-tools\adb.exe"
apk_path = r"C:\Users\Pravi\family_health_connect\family_health_mobile\build\app\outputs\flutter-apk\app-debug.apk"
if not os.path.exists(apk_path):
    apk_path = r"C:\Users\Pravi\family_health_connect\family_health_mobile\build\app\outputs\flutter-apk\app-release.apk"

print(f"1. Checking existing ADB devices for {target_ip}...")
dev_res = subprocess.run([adb_path, "devices"], capture_output=True, text=True)

target_device = None
for line in dev_res.stdout.splitlines():
    if target_ip in line and "\tdevice" in line:
        target_device = line.split()[0]
        break

if not target_device:
    print(f"2. Scanning open ADB ports on {target_ip}...")
    def check_port(port):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(0.3)
            res = s.connect_ex((target_ip, port))
            s.close()
            if res == 0:
                return port
        except:
            pass
        return None

    from concurrent.futures import ThreadPoolExecutor
    ports_to_check = [37705, 5555] + list(range(30000, 50000))
    found_port = None
    with ThreadPoolExecutor(max_workers=100) as executor:
        results = executor.map(check_port, ports_to_check)
        for p in results:
            if p:
                found_port = p
                break

    if not found_port:
        print(f"No open ADB port found on {target_ip}. Make sure Wireless Debugging is ON in Developer Options.")
        sys.exit(1)

    target_device = f"{target_ip}:{found_port}"
    print(f"Connecting ADB to {target_device}...")
    subprocess.run([adb_path, "connect", target_device], capture_output=True, text=True)

print(f"4. Installing APK to target device '{target_device}' ({apk_path})...")
inst_res = subprocess.run([adb_path, "-s", target_device, "install", "-r", apk_path], capture_output=True, text=True)
print(inst_res.stdout)

if "Success" in inst_res.stdout:
    print("=========================================")
    print("SUCCESS: APK INSTALLED & UPDATED SUCCESSFULLY!")
    print("=========================================")
else:
    print(f"Install error output:\n{inst_res.stderr}")
