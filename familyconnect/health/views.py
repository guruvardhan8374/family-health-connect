import logging
from datetime import timedelta, date

from django.utils import timezone
from django.db.models import Avg, Sum, Max, Min
from django.db.models.functions import TruncDate, TruncWeek
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import HealthSnapshot, HealthGoal, HealthMetric, HealthAlert
from .serializers import (
    HealthSnapshotSerializer, HealthGoalSerializer,
    HealthMetricSerializer, HealthAlertSerializer,
    HealthSummarySerializer,
)

logger = logging.getLogger(__name__)

# ─── Alert thresholds ──────────────────────────────────────────────────────
HR_HIGH  = 120   # bpm
HR_LOW   = 45    # bpm
SPO2_LOW = 90    # %


def _check_and_create_alerts(snapshot: HealthSnapshot):
    """Auto-generate HealthAlert records and broadcast via WebSocket if thresholds crossed."""
    alerts_created = []

    if snapshot.heart_rate is not None:
        if snapshot.heart_rate > HR_HIGH:
            alert = HealthAlert.objects.create(
                user=snapshot.user,
                alert_type='HIGH_HR',
                severity='CRITICAL',
                title='High Heart Rate Detected',
                message=f'Your heart rate is {snapshot.heart_rate:.0f} bpm, above the safe threshold of {HR_HIGH} bpm.',
                snapshot=snapshot,
            )
            alerts_created.append(alert)
        elif snapshot.heart_rate < HR_LOW:
            alert = HealthAlert.objects.create(
                user=snapshot.user,
                alert_type='LOW_HR',
                severity='CRITICAL',
                title='Low Heart Rate Detected',
                message=f'Your heart rate is {snapshot.heart_rate:.0f} bpm, below the safe threshold of {HR_LOW} bpm.',
                snapshot=snapshot,
            )
            alerts_created.append(alert)

    if snapshot.spo2 is not None and snapshot.spo2 < SPO2_LOW:
        alert = HealthAlert.objects.create(
            user=snapshot.user,
            alert_type='LOW_SPO2',
            severity='CRITICAL',
            title='Low Blood Oxygen',
            message=f'Your SpO₂ is {snapshot.spo2:.0f}%, below the safe threshold of {SPO2_LOW}%.',
            snapshot=snapshot,
        )
        alerts_created.append(alert)

    # Broadcast to WebSocket group
    if alerts_created:
        try:
            channel_layer = get_channel_layer()
            group = f'health_{snapshot.user.id}'
            payload = {
                'type': 'health.alert',
                'alerts': [
                    {
                        'id': a.id,
                        'alert_type': a.alert_type,
                        'severity': a.severity,
                        'title': a.title,
                        'message': a.message,
                    }
                    for a in alerts_created
                ],
            }
            async_to_sync(channel_layer.group_send)(group, payload)
        except Exception as e:
            logger.warning(f'Failed to broadcast health alert via WebSocket: {e}')

    return alerts_created


def _broadcast_snapshot(snapshot: HealthSnapshot):
    """Broadcast a health.update event to React dashboard and any listeners."""
    try:
        channel_layer = get_channel_layer()
        group = f'health_{snapshot.user.id}'
        payload = {
            'type': 'health.update',
            'snapshot': {
                'id': snapshot.id,
                'recorded_at': snapshot.recorded_at.isoformat(),
                'heart_rate': snapshot.heart_rate,
                'steps': snapshot.steps,
                'calories': snapshot.calories,
                'distance': snapshot.distance,
                'sleep_hours': snapshot.sleep_hours,
                'spo2': snapshot.spo2,
                'hydration': snapshot.hydration,
                'weight': snapshot.weight,
                'height': snapshot.height,
                'bmi': snapshot.bmi,
                'blood_pressure': snapshot.blood_pressure,
            },
        }
        async_to_sync(channel_layer.group_send)(group, payload)
    except Exception as e:
        logger.warning(f'Failed to broadcast health snapshot via WebSocket: {e}')


class HealthSnapshotViewSet(viewsets.ModelViewSet):
    serializer_class = HealthSnapshotSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return HealthSnapshot.objects.filter(user=self.request.user)

    @action(detail=False, methods=['get'])
    def live(self, request):
        """Get the single most recent health snapshot for the authenticated user."""
        snapshot = HealthSnapshot.objects.filter(user=request.user).first()
        if not snapshot:
            return Response({'detail': 'No snapshots found.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = self.get_serializer(snapshot)
        return Response(serializer.data)

    def perform_create(self, serializer):
        snapshot = serializer.save(user=self.request.user)
        # Check thresholds and send WebSocket broadcasts
        _check_and_create_alerts(snapshot)
        _broadcast_snapshot(snapshot)

        # Also fire the generic health.update event the existing SyncConsumer understands
        try:
            channel_layer = get_channel_layer()
            user = self.request.user
            # Broadcast to the user's personal sync group
            group = f'sync_user_{user.id}'
            async_to_sync(channel_layer.group_send)(group, {
                'type': 'health_update',
                'section': 'snapshot',
                'data': serializer.data
            })
        except Exception:
            pass


class HealthGoalViewSet(viewsets.ModelViewSet):
    serializer_class = HealthGoalSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return HealthGoal.objects.filter(user=self.request.user)

    def get_or_create_goal(self):
        goal, _ = HealthGoal.objects.get_or_create(user=self.request.user)
        return goal

    def list(self, request, *args, **kwargs):
        goal = self.get_or_create_goal()
        serializer = self.get_serializer(goal)
        return Response(serializer.data)

    def create(self, request, *args, **kwargs):
        # Upsert pattern — only one goal per user
        goal, _ = HealthGoal.objects.get_or_create(user=request.user)
        serializer = self.get_serializer(goal, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)


class HealthAlertViewSet(viewsets.ModelViewSet):
    serializer_class = HealthAlertSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return HealthAlert.objects.filter(user=self.request.user)

    @action(detail=False, methods=['post'], url_path='mark-all-read')
    def mark_all_read(self, request):
        HealthAlert.objects.filter(user=request.user, is_read=False).update(is_read=True)
        return Response({'status': 'ok'})


class HealthMetricViewSet(viewsets.ModelViewSet):
    """Legacy viewset — kept for backwards compatibility."""
    serializer_class = HealthMetricSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return HealthMetric.objects.filter(user=self.request.user)


def _safe_round(val, decimals=1):
    try:
        return round(float(val), decimals) if val is not None else None
    except (TypeError, ValueError):
        return None


class HealthSummaryView(APIView):
    """
    GET /health/summary/?range=daily|weekly|monthly
    Returns aggregated time-series data for charts plus today's totals.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        range_param = request.query_params.get('range', 'daily').lower()
        user = request.user
        now = timezone.now()
        today = now.date()

        if range_param == 'daily':
            # Last 7 days, one point per day
            days = 7
            start = today - timedelta(days=days - 1)
            dates = [start + timedelta(days=i) for i in range(days)]
            labels = [d.strftime('%a') for d in dates]

            # Aggregate per day
            qs = (
                HealthSnapshot.objects
                .filter(user=user, recorded_at__date__gte=start)
                .annotate(day=TruncDate('recorded_at'))
                .values('day')
                .annotate(
                    avg_hr=Avg('heart_rate'),
                    total_steps=Sum('steps'),
                    total_calories=Sum('calories'),
                    total_distance=Sum('distance'),
                    avg_sleep=Avg('sleep_hours'),
                    avg_spo2=Avg('spo2'),
                    total_hydration=Sum('hydration'),
                )
                .order_by('day')
            )
            data_by_day = {row['day']: row for row in qs}

            heart_rate = [_safe_round(data_by_day.get(d, {}).get('avg_hr')) for d in dates]
            steps      = [_safe_round(data_by_day.get(d, {}).get('total_steps'), 0) or 0 for d in dates]
            calories   = [_safe_round(data_by_day.get(d, {}).get('total_calories'), 0) or 0 for d in dates]
            distance   = [_safe_round(data_by_day.get(d, {}).get('total_distance')) or 0 for d in dates]
            sleep      = [_safe_round(data_by_day.get(d, {}).get('avg_sleep')) for d in dates]
            spo2       = [_safe_round(data_by_day.get(d, {}).get('avg_spo2')) for d in dates]
            hydration  = [_safe_round(data_by_day.get(d, {}).get('total_hydration')) or 0 for d in dates]

        elif range_param == 'weekly':
            # Last 4 weeks
            weeks = 4
            labels = [f'W-{weeks - i}' for i in range(weeks)]
            start = today - timedelta(weeks=weeks)

            qs = (
                HealthSnapshot.objects
                .filter(user=user, recorded_at__date__gte=start)
                .annotate(week=TruncWeek('recorded_at'))
                .values('week')
                .annotate(
                    avg_hr=Avg('heart_rate'),
                    total_steps=Sum('steps'),
                    total_calories=Sum('calories'),
                    total_distance=Sum('distance'),
                    avg_sleep=Avg('sleep_hours'),
                    avg_spo2=Avg('spo2'),
                    total_hydration=Sum('hydration'),
                )
                .order_by('week')
            )
            data_list = list(qs)
            _pad = lambda field, agg_fn: [_safe_round(row.get(field)) or 0 for row in data_list]

            heart_rate = [_safe_round(r.get('avg_hr')) for r in data_list]
            steps      = [_safe_round(r.get('total_steps'), 0) or 0 for r in data_list]
            calories   = [_safe_round(r.get('total_calories'), 0) or 0 for r in data_list]
            distance   = [_safe_round(r.get('total_distance')) or 0 for r in data_list]
            sleep      = [_safe_round(r.get('avg_sleep')) for r in data_list]
            spo2       = [_safe_round(r.get('avg_spo2')) for r in data_list]
            hydration  = [_safe_round(r.get('total_hydration')) or 0 for r in data_list]
            labels     = labels[:len(data_list)]

        elif range_param == 'monthly':
            # Last 12 months, one point per month
            import calendar
            months = 12
            labels = []
            heart_rate = []; steps = []; calories = []
            distance = []; sleep = []; spo2 = []; hydration = []

            for i in range(months - 1, -1, -1):
                month_date = (today.replace(day=1) - timedelta(days=i * 28)).replace(day=1)
                _, last_day = calendar.monthrange(month_date.year, month_date.month)
                m_end = month_date.replace(day=last_day)
                labels.append(month_date.strftime('%b'))

                qs = HealthSnapshot.objects.filter(
                    user=user,
                    recorded_at__date__gte=month_date,
                    recorded_at__date__lte=m_end,
                )
                agg = qs.aggregate(
                    avg_hr=Avg('heart_rate'),
                    total_steps=Sum('steps'),
                    total_calories=Sum('calories'),
                    total_distance=Sum('distance'),
                    avg_sleep=Avg('sleep_hours'),
                    avg_spo2=Avg('spo2'),
                    total_hydration=Sum('hydration'),
                )
                heart_rate.append(_safe_round(agg['avg_hr']))
                steps.append(_safe_round(agg['total_steps'], 0) or 0)
                calories.append(_safe_round(agg['total_calories'], 0) or 0)
                distance.append(_safe_round(agg['total_distance']) or 0)
                sleep.append(_safe_round(agg['avg_sleep']))
                spo2.append(_safe_round(agg['avg_spo2']))
                hydration.append(_safe_round(agg['total_hydration']) or 0)
        else:
            return Response({'error': 'Invalid range. Use daily, weekly, or monthly.'}, status=400)

        # ── Today's totals ─────────────────────────────────────────────────
        today_qs = HealthSnapshot.objects.filter(user=user, recorded_at__date=today)
        today_agg = today_qs.aggregate(
            total_steps=Sum('steps'),
            total_calories=Sum('calories'),
            total_hydration=Sum('hydration'),
            avg_sleep=Avg('sleep_hours'),
            total_distance=Sum('distance'),
        )
        latest = HealthSnapshot.objects.filter(user=user).first()
        latest_hr   = _safe_round(latest.heart_rate) if latest else None
        latest_spo2 = _safe_round(latest.spo2) if latest else None
        latest_bmi  = _safe_round(latest.bmi) if latest else None

        today_steps    = _safe_round(today_agg['total_steps'], 0)
        today_calories = _safe_round(today_agg['total_calories'], 0)
        today_hydration = _safe_round(today_agg['total_hydration'])
        today_sleep    = _safe_round(today_agg['avg_sleep'])
        today_distance = _safe_round(today_agg['total_distance'])

        # ── Goals ─────────────────────────────────────────────────────────
        goal, _ = HealthGoal.objects.get_or_create(user=user)
        goal_data = HealthGoalSerializer(goal, context={'request': request}).data

        def progress(actual, goal_val):
            if actual and goal_val and goal_val > 0:
                return _safe_round(min(actual / goal_val, 1.0), 3)
            return 0.0

        # ── Active alerts (unread) ─────────────────────────────────────────
        active_alerts = HealthAlert.objects.filter(user=user, is_read=False)[:5]
        alerts_data = HealthAlertSerializer(active_alerts, many=True).data

        return Response({
            'range': range_param,
            'labels': labels,
            'heart_rate': heart_rate,
            'steps': steps,
            'calories': calories,
            'distance': distance,
            'sleep_hours': sleep,
            'spo2': spo2,
            'hydration': hydration,
            # Today
            'today_steps': today_steps,
            'today_calories': today_calories,
            'today_hydration': today_hydration,
            'today_sleep': today_sleep,
            'today_distance': today_distance,
            'latest_heart_rate': latest_hr,
            'latest_spo2': latest_spo2,
            'latest_bmi': latest_bmi,
            # Goals
            'goal': goal_data,
            'steps_progress': progress(today_steps, goal.steps_goal),
            'calories_progress': progress(today_calories, goal.calories_goal),
            'hydration_progress': progress(today_hydration, goal.hydration_goal),
            'sleep_progress': progress(today_sleep, goal.sleep_goal),
            'distance_progress': progress(today_distance, goal.distance_goal),
            # Alerts
            'active_alerts': alerts_data,
        })


class FamilyHealthSummaryView(APIView):
    """
    GET /health/family-summary/
    Returns the latest snapshot for every member in the requester's family circle.
    Only accessible to family admins (is_admin=True in their membership).
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from family.models import FamilyMembership
        user = request.user

        # Get all family groups where this user is a member
        memberships = FamilyMembership.objects.filter(
            user=user, status='ACTIVE', is_approved=True
        ).select_related('family_group')

        result = []
        seen_users = set()

        for membership in memberships:
            group = membership.family_group
            # All members of this family
            group_members = FamilyMembership.objects.filter(
                family_group=group, status='ACTIVE', is_approved=True
            ).select_related('user')

            for member_ship in group_members:
                member = member_ship.user
                if member.id in seen_users:
                    continue
                seen_users.add(member.id)

                latest = HealthSnapshot.objects.filter(user=member).first()
                result.append({
                    'user_id': member.id,
                    'username': member.username,
                    'label': member_ship.label,
                    'latest_snapshot': HealthSnapshotSerializer(latest).data if latest else None,
                })

        return Response(result)


class HealthSummaryTodayView(APIView):
    """
    GET /health/summary/today/
    Returns aggregated fitness data for today:
    - steps: sum of steps today
    - distance: sum of distance today
    - heart_rate: latest heart rate reading
    - blood_pressure: latest blood pressure reading ("systolic/diastolic")
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        today = timezone.localdate()

        # Sum steps logged today
        steps_today = HealthMetric.objects.filter(
            user=user,
            metric_type='STEPS',
            recorded_at__date=today
        ).aggregate(total=Sum('value'))['total'] or 0.0

        # Sum distance logged today
        distance_today = HealthMetric.objects.filter(
            user=user,
            metric_type='DISTANCE',
            recorded_at__date=today
        ).aggregate(total=Sum('value'))['total'] or 0.0

        # Latest heart rate reading (fallback to overall latest for better UX)
        latest_hr_obj = HealthMetric.objects.filter(
            user=user,
            metric_type='HEART_RATE'
        ).order_by('-recorded_at').first()
        latest_hr = latest_hr_obj.value if latest_hr_obj else None

        # Latest blood pressure readings (overall)
        latest_sys_obj = HealthMetric.objects.filter(
            user=user,
            metric_type='BLOOD_PRESSURE_SYSTOLIC'
        ).order_by('-recorded_at').first()

        latest_dia_obj = HealthMetric.objects.filter(
            user=user,
            metric_type='BLOOD_PRESSURE_DIASTOLIC'
        ).order_by('-recorded_at').first()

        blood_pressure = None
        if latest_sys_obj and latest_dia_obj:
            blood_pressure = f"{int(latest_sys_obj.value)}/{int(latest_dia_obj.value)}"

        return Response({
            'steps': int(steps_today),
            'distance': round(float(distance_today), 2),
            'blood_pressure': blood_pressure,
            'heart_rate': int(latest_hr) if latest_hr else None
        }, status=status.HTTP_200_OK)
