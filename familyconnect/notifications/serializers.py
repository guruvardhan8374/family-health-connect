from rest_framework import serializers
from .models import Notification, Reminder

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'user', 'type', 'title', 'message', 'is_read', 'data', 'priority', 'created_at']
        read_only_fields = ['id', 'user', 'created_at']

class ReminderSerializer(serializers.ModelSerializer):
    class Meta:
        model = Reminder
        fields = ['id', 'user', 'reminder_type', 'title', 'message', 'time', 'repeat_days', 'is_active', 'created_at']
        read_only_fields = ['id', 'user', 'created_at']

    def validate_repeat_days(self, value):
        valid_days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        for day in value:
            if day not in valid_days:
                raise serializers.ValidationError(f"'{day}' is not a valid weekday name.")
        return value
