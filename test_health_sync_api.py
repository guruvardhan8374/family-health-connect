import os
import sys
import json

print("=" * 60)
print("  TESTING /api/health-sync RANGE PARAMETERS (day, week, month)")
print("=" * 60)

# Setup Django environment
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'familyconnect'))
os.environ['DJANGO_SETTINGS_MODULE'] = 'familyconnect.settings'

import django
django.setup()

from django.test import RequestFactory
from health.views import HealthSyncAPIView
from users.models import CustomUser

factory = RequestFactory()
view = HealthSyncAPIView.as_view()

user = CustomUser.objects.get(username='guru')

# ── 1. TEST GET range=day ───────────────────────────────────────────────────
print("\n--- 1. Testing GET /api/health-sync?userId=...&range=day ---")
req_day = factory.get(f'/api/health-sync?userId={user.id}&range=day')
res_day = view(req_day)
print(f"Status Code: {res_day.status_code}")
print(f"Response   : {res_day.data}")
assert res_day.status_code == 200
assert res_day.data['range'] == 'day'

# ── 2. TEST GET range=week ──────────────────────────────────────────────────
print("\n--- 2. Testing GET /api/health-sync?userId=...&range=week ---")
req_week = factory.get(f'/api/health-sync?userId={user.id}&range=week')
res_week = view(req_week)
print(f"Status Code: {res_week.status_code}")
print(f"Response   : {res_week.data}")
assert res_week.status_code == 200
assert res_week.data['range'] == 'week'

# ── 3. TEST GET range=month ─────────────────────────────────────────────────
print("\n--- 3. Testing GET /api/health-sync?userId=...&range=month ---")
req_month = factory.get(f'/api/health-sync?userId={user.id}&range=month')
res_month = view(req_month)
print(f"Status Code: {res_month.status_code}")
print(f"Response   : {res_month.data}")
assert res_month.status_code == 200
assert res_month.data['range'] == 'month'

print("\n============================================================")
print("  ALL RANGE PARAMETER API TESTS PASSED SUCCESSFULLY! - PASS")
print("============================================================")
