from rest_framework import serializers
from .models import Medicine, MedicineDoseLog


class MedicineSerializer(serializers.ModelSerializer):
    class Meta:
        model = Medicine
        fields = [
            'id',
            'user',
            'name',
            'dosage',
            'dosage_unit',
            'frequency',
            'reminder_times',
            'start_date',
            'end_date',
            'notes',
            'is_active',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'user', 'created_at', 'updated_at']

    def validate_reminder_times(self, value):
        if not isinstance(value, list):
            raise serializers.ValidationError("reminder_times must be a list of time strings (e.g. ['08:00']).")
        if len(value) == 0:
            raise serializers.ValidationError("Please specify at least one reminder time.")
        for item in value:
            if not isinstance(item, str) or len(item.strip()) == 0:
                raise serializers.ValidationError("Each reminder time must be a valid time string (HH:MM).")
        return [item.strip() for item in value]

    def validate(self, data):
        start_date = data.get('start_date') or (self.instance.start_date if self.instance else None)
        end_date = data.get('end_date') if 'end_date' in data else (self.instance.end_date if self.instance else None)
        if start_date and end_date and end_date < start_date:
            raise serializers.ValidationError({"end_date": "End date cannot be earlier than start date."})
        return data


class MedicineDoseLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = MedicineDoseLog
        fields = [
            'id',
            'medicine',
            'user',
            'scheduled_date',
            'dose_time',
            'taken_at',
            'status',
            'created_at',
        ]
        read_only_fields = ['id', 'user', 'created_at']
