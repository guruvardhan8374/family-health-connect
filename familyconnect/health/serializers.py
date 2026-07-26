from rest_framework import serializers
from .models import HealthSnapshot, HealthGoal, HealthMetric, HealthAlert


class HealthSnapshotSerializer(serializers.ModelSerializer):
    bmi = serializers.ReadOnlyField()
    user = serializers.HiddenField(default=serializers.CurrentUserDefault())

    class Meta:
        model = HealthSnapshot
        fields = [
            'id', 'user', 'recorded_at', 'source',
            'heart_rate', 'steps', 'calories', 'distance',
            'sleep_hours', 'spo2', 'hydration', 'weight', 'height',
            'blood_pressure', 'notes', 'bmi',
            'sleep_light', 'sleep_deep', 'sleep_rem', 'sleep_awake',
            'body_fat', 'exercise_count', 'device_name',
        ]
        read_only_fields = ['id', 'bmi']


class HealthGoalSerializer(serializers.ModelSerializer):
    user = serializers.HiddenField(default=serializers.CurrentUserDefault())

    class Meta:
        model = HealthGoal
        fields = [
            'id', 'user',
            'steps_goal', 'calories_goal', 'hydration_goal',
            'sleep_goal', 'distance_goal', 'updated_at',
        ]
        read_only_fields = ['id', 'updated_at']


class HealthMetricSerializer(serializers.ModelSerializer):
    user = serializers.HiddenField(default=serializers.CurrentUserDefault())

    class Meta:
        model = HealthMetric
        fields = '__all__'
        read_only_fields = ['id', 'recorded_at']


class HealthAlertSerializer(serializers.ModelSerializer):
    class Meta:
        model = HealthAlert
        fields = '__all__'
        read_only_fields = ['id', 'created_at']


class HealthSummarySerializer(serializers.Serializer):
    """
    Read-only aggregated summary for charts.
    Returned by HealthSummaryView.
    """
    range = serializers.CharField()          # daily | weekly | monthly
    labels = serializers.ListField()         # x-axis labels
    heart_rate = serializers.ListField()
    steps = serializers.ListField()
    calories = serializers.ListField()
    distance = serializers.ListField()
    sleep_hours = serializers.ListField()
    spo2 = serializers.ListField()
    hydration = serializers.ListField()

    # Totals for today (or last day in range)
    today_steps = serializers.FloatField(allow_null=True)
    today_calories = serializers.FloatField(allow_null=True)
    today_hydration = serializers.FloatField(allow_null=True)
    today_sleep = serializers.FloatField(allow_null=True)
    today_distance = serializers.FloatField(allow_null=True)
    latest_heart_rate = serializers.FloatField(allow_null=True)
    latest_spo2 = serializers.FloatField(allow_null=True)
    latest_bmi = serializers.FloatField(allow_null=True)

    # Goal progress (0.0–1.0)
    goal = HealthGoalSerializer(allow_null=True)
    steps_progress = serializers.FloatField(allow_null=True)
    calories_progress = serializers.FloatField(allow_null=True)
    hydration_progress = serializers.FloatField(allow_null=True)
    sleep_progress = serializers.FloatField(allow_null=True)
    distance_progress = serializers.FloatField(allow_null=True)

    # Active alerts
    active_alerts = HealthAlertSerializer(many=True)
