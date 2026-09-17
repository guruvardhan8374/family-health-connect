from datetime import datetime, time
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APITestCase
from rest_framework import status
from .models import Medicine, MedicineDoseLog

User = get_user_model()


class MedicineReminderAPITests(APITestCase):
    def setUp(self):
        self.user1 = User.objects.create_user(
            username='alice',
            password='testpassword123',
            email='alice@example.com'
        )
        self.user2 = User.objects.create_user(
            username='bob',
            password='testpassword123',
            email='bob@example.com'
        )
        self.client.force_authenticate(user=self.user1)

    def test_create_and_list_medicine(self):
        payload = {
            'name': 'Paracetamol',
            'dosage': '500',
            'dosage_unit': 'Tablet',
            'frequency': 'TWICE_DAILY',
            'reminder_times': ['08:00', '20:00'],
            'start_date': str(timezone.localdate()),
            'notes': 'Take after food',
            'is_active': True
        }
        res = self.client.post('/api/v1/medicines/', payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['name'], 'Paracetamol')
        self.assertEqual(res.data['dosage'], '500')
        self.assertEqual(len(res.data['reminder_times']), 2)

        # List medicines
        list_res = self.client.get('/api/v1/medicines/')
        self.assertEqual(list_res.status_code, status.HTTP_200_OK)
        results = list_res.data['results'] if isinstance(list_res.data, dict) and 'results' in list_res.data else list_res.data
        self.assertEqual(len(results), 1)

    def test_security_isolation(self):
        # User 1 creates a medicine
        med = Medicine.objects.create(
            user=self.user1,
            name='User1 Medicine',
            dosage='1',
            dosage_unit='Tablet',
            frequency='ONCE_DAILY',
            reminder_times=['09:00'],
            start_date=timezone.localdate()
        )

        # User 2 logs in and tries to access User 1's medicine
        self.client.force_authenticate(user=self.user2)
        res = self.client.get(f'/api/v1/medicines/{med.id}/')
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)

        list_res = self.client.get('/api/v1/medicines/')
        results = list_res.data['results'] if isinstance(list_res.data, dict) and 'results' in list_res.data else list_res.data
        self.assertEqual(len(results), 0)

    def test_today_medicines_and_missed_status(self):
        # Create a dose with time in past (00:01) and time in future (23:59)
        med = Medicine.objects.create(
            user=self.user1,
            name='Daily Vitamin',
            dosage='1',
            dosage_unit='Capsule',
            frequency='TWICE_DAILY',
            reminder_times=['00:01', '23:59'],
            start_date=timezone.localdate(),
            is_active=True
        )

        res = self.client.get('/api/v1/medicines/today/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['total_doses'], 2)

        doses = res.data['doses']
        # 00:01 should be MISSED (unless running at 00:00)
        # 23:59 should be UPCOMING (unless running at 23:59:59)
        d_past = [d for d in doses if d['dose_time'] == '00:01'][0]
        d_future = [d for d in doses if d['dose_time'] == '23:59'][0]

        self.assertEqual(d_past['status'], 'MISSED')
        self.assertEqual(d_future['status'], 'UPCOMING')

    def test_mark_taken_and_duplicate_prevention(self):
        med = Medicine.objects.create(
            user=self.user1,
            name='Aspirin',
            dosage='100',
            dosage_unit='mg',
            frequency='ONCE_DAILY',
            reminder_times=['08:00'],
            start_date=timezone.localdate(),
            is_active=True
        )

        # First mark as taken
        res1 = self.client.post(f'/api/v1/medicines/{med.id}/taken/', {'dose_time': '08:00'}, format='json')
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res1.data['created'])

        # Check in today's list: should now be TAKEN
        today_res = self.client.get('/api/v1/medicines/today/')
        dose_item = today_res.data['doses'][0]
        self.assertEqual(dose_item['status'], 'TAKEN')
        self.assertIsNotNone(dose_item['taken_at'])

        # Attempt to mark as taken again (duplicate prevention)
        res2 = self.client.post(f'/api/v1/medicines/{med.id}/taken/', {'dose_time': '08:00'}, format='json')
        self.assertEqual(res2.status_code, status.HTTP_200_OK)
        self.assertFalse(res2.data['created'])
        self.assertIn("already recorded as taken", res2.data['message'])

        # Ensure only 1 record exists in DB
        self.assertEqual(MedicineDoseLog.objects.filter(medicine=med, dose_time='08:00').count(), 1)
