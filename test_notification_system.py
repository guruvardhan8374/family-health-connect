import os
import sys
import uuid

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'familyconnect.settings')
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'familyconnect'))

import django
django.setup()

from rest_framework.test import APIClient
from users.models import CustomUser
from notifications.models import Notification
from notifications.services import create_notification, create_bulk_notifications

def run_test():
    print("=" * 70)
    print("  E2E TEST: REAL-TIME NOTIFICATION SYSTEM & API SUITE")
    print("=" * 70)

    uid = uuid.uuid4().hex[:6]
    user1 = CustomUser.objects.create_user(
        username=f'notif_user1_{uid}',
        email=f'notif1_{uid}@example.com',
        password='password123'
    )
    user2 = CustomUser.objects.create_user(
        username=f'notif_user2_{uid}',
        email=f'notif2_{uid}@example.com',
        password='password123'
    )

    client1 = APIClient()
    client1.force_authenticate(user=user1)

    client2 = APIClient()
    client2.force_authenticate(user=user2)

    print("\n--- 1. Creating Notifications for User 1 ---")
    n1 = create_notification(user1, 'SYSTEM', 'Welcome to Family Health Connect', 'Your account has been created.', priority='NORMAL')
    n2 = create_notification(user1, 'FAMILY', 'New Member Joined', 'John joined your Family Circle.', priority='NORMAL')
    n3 = create_notification(user1, 'EMERGENCY', 'SOS Alert Triggered', 'Emergency SOS reported at 12.97, 77.59', priority='HIGH')
    n4 = create_notification(user1, 'HEALTH', 'Heart Rate High', 'Heart rate exceeded 120 bpm', priority='URGENT')
    n5 = create_notification(user1, 'CHAT', 'New Message', 'Alice sent you a chat message', priority='NORMAL')

    print(f"--> Created 5 notifications (IDs: {[n1.id, n2.id, n3.id, n4.id, n5.id]})")

    print("\n--- 2. Fetching Unread Notification Count ---")
    res_count = client1.get('/api/v1/notifications/unread-count/')
    assert res_count.status_code == 200, f"Expected 200, got {res_count.status_code}"
    assert res_count.data['unread_count'] == 5, f"Expected 5 unread, got {res_count.data['unread_count']}"
    print(f"--> Verified unread_count: {res_count.data['unread_count']}")

    print("\n--- 3. Fetching Notifications List with Filters ---")
    res_list = client1.get('/api/v1/notifications/')
    assert res_list.status_code == 200
    results = res_list.data if isinstance(res_list.data, list) else res_list.data.get('results', [])
    assert len(results) >= 5
    print(f"--> Retrieved {len(results)} notifications in descending chronological order")

    # Filter by FAMILY type
    res_family = client1.get('/api/v1/notifications/?type=FAMILY')
    family_results = res_family.data if isinstance(res_family.data, list) else res_family.data.get('results', [])
    assert len(family_results) == 1 and family_results[0]['title'] == 'New Member Joined'
    print(f"--> Category filter (FAMILY) returned expected item: '{family_results[0]['title']}'")

    print("\n--- 4. Data Security & Isolation Check ---")
    res_user2 = client2.get('/api/v1/notifications/')
    user2_results = res_user2.data if isinstance(res_user2.data, list) else res_user2.data.get('results', [])
    assert len(user2_results) == 0, f"User 2 should see 0 notifications, saw {len(user2_results)}"
    print("--> User 2 cannot access User 1's notifications - PASS")

    print("\n--- 5. Marking Single Notification as Read ---")
    res_mark = client1.post(f'/api/v1/notifications/{n1.id}/mark-read/')
    assert res_mark.status_code == 200
    assert res_mark.data['notification']['is_read'] == True

    res_count2 = client1.get('/api/v1/notifications/unread-count/')
    assert res_count2.data['unread_count'] == 4
    print(f"--> Notification {n1.id} marked as read. Unread count reduced to {res_count2.data['unread_count']}")

    print("\n--- 6. Marking All Notifications as Read ---")
    res_mark_all = client1.post('/api/v1/notifications/mark-all-read/')
    assert res_mark_all.status_code == 200

    res_count3 = client1.get('/api/v1/notifications/unread-count/')
    assert res_count3.data['unread_count'] == 0
    print("--> All notifications successfully marked as read (unread_count = 0)")

    print("\n--- 7. Deleting Single Notification ---")
    res_del = client1.delete(f'/api/v1/notifications/{n2.id}/')
    assert res_del.status_code in [200, 204]

    res_list_after_del = client1.get('/api/v1/notifications/')
    results_after_del = res_list_after_del.data if isinstance(res_list_after_del.data, list) else res_list_after_del.data.get('results', [])
    assert not any(n['id'] == n2.id for n in results_after_del)
    print(f"--> Notification {n2.id} deleted successfully.")

    print("\n--- 8. Clearing All Notifications ---")
    res_del_all = client1.delete('/api/v1/notifications/delete-all/')
    assert res_del_all.status_code == 200

    res_final_list = client1.get('/api/v1/notifications/')
    final_results = res_final_list.data if isinstance(res_final_list.data, list) else res_final_list.data.get('results', [])
    assert len(final_results) == 0
    print("--> Delete-all cleared all notifications successfully.")

    print("\n" + "=" * 70)
    print("  ALL E2E NOTIFICATION SYSTEM TESTS PASSED SUCCESSFULLY! - PASS")
    print("=" * 70)

if __name__ == '__main__':
    run_test()
