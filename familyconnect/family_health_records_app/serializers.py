from rest_framework import serializers
from .models import HealthRecord
from .services import calculate_bmi

class HealthRecordSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = HealthRecord
        fields = [
            'id', 'user', 'username', 'recorded_date', 'heart_rate', 'oxygen_level', 
            'blood_pressure', 'sleep_hours', 'water_intake', 'calories_burned', 'steps', 
            'weight', 'height', 'bmi', 'stress_level', 'notes', 'created_at'
        ]
        read_only_fields = ['id', 'user', 'bmi', 'created_at']

    def validate_heart_rate(self, value):
        if value < 0 or value > 250:
            raise serializers.ValidationError("Heart rate must be between 0 and 250 bpm.")
        return value

    def validate_oxygen_level(self, value):
        if value < 0 or value > 100:
            raise serializers.ValidationError("Oxygen level must be between 0 and 100 percent.")
        return value

    def validate_stress_level(self, value):
        if value < 0 or value > 10:
            raise serializers.ValidationError("Stress level must be on a scale of 0 to 10.")
        return value

    def validate_steps(self, value):
        if value < 0:
            raise serializers.ValidationError("Steps cannot be negative.")
        return value

    def validate_sleep_hours(self, value):
        if value < 0 or value > 24:
            raise serializers.ValidationError("Sleep hours must be between 0 and 24.")
        return value

    def validate(self, attrs):
        # Auto-compute BMI if height and weight are provided
        weight = attrs.get('weight') or (self.instance.weight if self.instance else 0.0)
        height = attrs.get('height') or (self.instance.height if self.instance else 0.0)
        
        if weight and height:
            attrs['bmi'] = calculate_bmi(weight, height)
            
        return attrs