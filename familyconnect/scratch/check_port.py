import socket

def check_port(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(1.0)
        try:
            s.connect(('127.0.0.1', port))
            return True
        except socket.error:
            return False

if __name__ == "__main__":
    for port in [8000, 5173, 8001]:
        open_status = "LISTENING" if check_port(port) else "CLOSED"
        print(f"Port {port}: {open_status}")
