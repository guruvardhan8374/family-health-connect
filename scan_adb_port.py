import socket
import subprocess
from concurrent.futures import ThreadPoolExecutor

target_ip = "192.168.1.4"
adb_path = r"C:\Users\Pravi\AppData\Local\Android\Sdk\platform-tools\adb.exe"

print(f"Scanning open ports on {target_ip} using 100 threads...")

def check_port(port):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.3)
        result = s.connect_ex((target_ip, port))
        s.close()
        if result == 0:
            return port
    except:
        pass
    return None

ports_to_check = [5555] + list(range(30000, 50000))
found_port = None

with ThreadPoolExecutor(max_workers=100) as executor:
    results = executor.map(check_port, ports_to_check)
    for p in results:
        if p:
            print(f"--> FOUND OPEN PORT: {p}")
            found_port = p
            break

if found_port:
    print(f"Connecting ADB to {target_ip}:{found_port}...")
    res = subprocess.run([adb_path, "connect", f"{target_ip}:{found_port}"], capture_output=True, text=True)
    print(res.stdout)
    devices = subprocess.run([adb_path, "devices"], capture_output=True, text=True)
    print("ADB Devices Output:\n" + devices.stdout)
else:
    print("No open ADB port found on 192.168.1.4.")
