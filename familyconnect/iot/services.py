import random
from datetime import datetime, timedelta
from health.models import HealthMetric
from .models import SyncHistory

class IoTDataSyncService:
    @staticmethod
    def sync_user_data(user, platform):
        """
        Mocks data synchronization from external IoT platforms.
        In a real scenario, this would authenticate with OAuth and call REST APIs.
        """
        sync_record = SyncHistory.objects.create(
            user=user,
            platform=platform,
            status='IN_PROGRESS'
        )

        try:
            # Mocking data retrieval
            new_metrics = []
            
            # 1. Sync Steps
            steps = random.randint(2000, 10000)
            new_metrics.append(HealthMetric(
                user=user, metric_type='STEPS', value=steps, unit='steps'
            ))

            # 2. Sync Heart Rate
            hr = random.randint(60, 100)
            new_metrics.append(HealthMetric(
                user=user, metric_type='HEART_RATE', value=hr, unit='bpm'
            ))

            # 3. Sync Sleep
            sleep_score = random.randint(60, 95)
            new_metrics.append(HealthMetric(
                user=user, metric_type='SLEEP', value=sleep_score, unit='score'
            ))

            # Bulk create metrics
            HealthMetric.objects.bulk_create(new_metrics)

            # Update sync record
            sync_record.status = 'SUCCESS'
            sync_record.data_points_synced = len(new_metrics)
            sync_record.save()

            return True
        except Exception as e:
            sync_record.status = 'FAILED'
            sync_record.save()
            print(f"Sync Error for {user.username}: {e}")
            return False
