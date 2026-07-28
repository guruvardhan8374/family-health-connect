import os
from pathlib import Path

# Base Paths
BASE_DIR = Path(__file__).resolve().parent.parent
REPORTS_DIR = BASE_DIR / "reports"
SCREENSHOTS_DIR = BASE_DIR / "screenshots"
LOGS_DIR = BASE_DIR / "logs"
DATA_DIR = BASE_DIR / "data"

# Create directories if not existing
for d in [REPORTS_DIR, SCREENSHOTS_DIR, LOGS_DIR, DATA_DIR, REPORTS_DIR / "Excel", REPORTS_DIR / "HTML", REPORTS_DIR / "JSON", REPORTS_DIR / "Summary"]:
    d.mkdir(parents=True, exist_ok=True)

# Application URL (Live Deployment URL — Never localhost in CI)
BASE_URL = os.getenv("BASE_URL", "https://guruvardhan8374.github.io/family-health-connect/").rstrip('/') + '/'

# Selenium Driver Configuration
HEADLESS = os.getenv("HEADLESS", "true").lower() == "true"
BROWSER = os.getenv("BROWSER", "chrome").lower()
IMPLICIT_WAIT = 10
EXPLICIT_WAIT = 15
WINDOW_SIZE = (1920, 1080)

# Pass / Fail Threshold Configuration
PASS_THRESHOLD_PERCENT = 95.0
MAX_CRITICAL_FAILURES_PERCENT = 5.0
