from datetime import datetime
from django.db import models
from django.utils import timezone
from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Medicine, MedicineDoseLog
from .serializers import MedicineSerializer, MedicineDoseLogSerializer


class MedicineViewSet(viewsets.ModelViewSet):
    serializer_class = MedicineSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Security: Users only access their own medicine records
        return Medicine.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=False, methods=['get'], url_path='today')
    def today(self, request):
        """
        Calculates medicines scheduled for today with their current status:
        - UPCOMING: Scheduled time is in the future
        - TAKEN: Already marked as taken for this dose time
        - MISSED: Scheduled time has passed without being marked as taken
        """
        user = request.user
        today_date = timezone.localdate()
        now_time = timezone.localtime().time()

        # Query active medicines active today
        active_medicines = Medicine.objects.filter(
            user=user,
            is_active=True,
            start_date__lte=today_date
        ).filter(
            models.Q(end_date__isnull=True) | models.Q(end_date__gte=today_date)
        )

        # Get all dose logs for today
        logs = MedicineDoseLog.objects.filter(
            user=user,
            scheduled_date=today_date
        )
        log_map = {(log.medicine_id, log.dose_time): log for log in logs}

        doses = []
        for med in active_medicines:
            times = med.reminder_times or []
            for t_str in times:
                t_str_clean = t_str.strip()
                log = log_map.get((med.id, t_str_clean))

                if log and log.status == 'TAKEN':
                    dose_status = 'TAKEN'
                    taken_at = log.taken_at.isoformat()
                    dose_log_id = log.id
                else:
                    dose_log_id = None
                    taken_at = None
                    # Compare time
                    try:
                        # Normalize time string to HH:MM
                        t_parts = [int(p) for p in t_str_clean.split(':')[:2]]
                        dose_hour, dose_minute = t_parts[0], t_parts[1]
                        dose_time_obj = datetime.now().time().replace(
                            hour=dose_hour, minute=dose_minute, second=0, microsecond=0
                        )
                        if now_time > dose_time_obj:
                            dose_status = 'MISSED'
                        else:
                            dose_status = 'UPCOMING'
                    except Exception:
                        dose_status = 'UPCOMING'

                doses.append({
                    'medicine_id': med.id,
                    'medicine_name': med.name,
                    'dosage': med.dosage,
                    'dosage_unit': med.dosage_unit,
                    'dose_time': t_str_clean,
                    'status': dose_status,
                    'taken_at': taken_at,
                    'notes': med.notes,
                    'dose_log_id': dose_log_id,
                    'is_active': med.is_active,
                })

        # Sort by scheduled time
        doses.sort(key=lambda d: d['dose_time'])

        summary = {
            'date': today_date.isoformat(),
            'total_doses': len(doses),
            'taken_doses': sum(1 for d in doses if d['status'] == 'TAKEN'),
            'missed_doses': sum(1 for d in doses if d['status'] == 'MISSED'),
            'upcoming_doses': sum(1 for d in doses if d['status'] == 'UPCOMING'),
            'doses': doses,
        }

        return Response(summary)

    @action(detail=True, methods=['post'], url_path='taken')
    def mark_taken(self, request, pk=None):
        """
        Marks a specific scheduled dose as taken for the medicine.
        Prevents duplicate records for the same scheduled dose.
        """
        medicine = self.get_object()
        dose_time = request.data.get('dose_time')
        scheduled_date_str = request.data.get('scheduled_date')

        if not dose_time:
            return Response(
                {"error": "dose_time (HH:MM) is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        dose_time = dose_time.strip()

        if scheduled_date_str:
            try:
                scheduled_date = datetime.strptime(scheduled_date_str, '%Y-%m-%d').date()
            except ValueError:
                return Response(
                    {"error": "Invalid scheduled_date format. Use YYYY-MM-DD."},
                    status=status.HTTP_400_BAD_REQUEST
                )
        else:
            scheduled_date = timezone.localdate()

        # Prevent duplicate entries for the same scheduled dose
        dose_log, created = MedicineDoseLog.objects.get_or_create(
            medicine=medicine,
            scheduled_date=scheduled_date,
            dose_time=dose_time,
            defaults={
                'user': request.user,
                'taken_at': timezone.now(),
                'status': 'TAKEN'
            }
        )

        if not created:
            # If already taken, ensure status is TAKEN and return existing log
            if dose_log.status != 'TAKEN':
                dose_log.status = 'TAKEN'
                dose_log.taken_at = timezone.now()
                dose_log.save(update_fields=['status', 'taken_at'])

            return Response({
                "message": "Dose already recorded as taken.",
                "created": False,
                "dose_log": MedicineDoseLogSerializer(dose_log).data
            }, status=status.HTTP_200_OK)

        return Response({
            "message": "Marked dose as taken successfully.",
            "created": True,
            "dose_log": MedicineDoseLogSerializer(dose_log).data
        }, status=status.HTTP_201_CREATED)
