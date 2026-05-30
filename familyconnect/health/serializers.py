from rest_framework import serializers
from .models import HealthMetric, HealthAlert

class HealthMetricSerializer(serializers.ModelSerializer):
    class Meta:
        model = HealthMetric
        fields = '__all__'
        read_only_fields = ['id', 'recorded_at']

class HealthAlertSerializer(serializers.ModelSerializer):
    class Meta:
        model = HealthAlert
        fields = '__all__'
        read_only_fields = ['id', 'created_at']
