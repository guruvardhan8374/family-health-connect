from rest_framework import serializers
from .models import Notification, Reminder

class NotificationSerializer(serializers.ModelSerializer):
    created_at_formatted = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = ['id', 'user', 'family_group', 'type', 'title', 'message', 'is_read', 'read_at', 'data', 'priority', 'created_at', 'created_at_formatted']
        read_only_fields = ['id', 'user', 'created_at', 'created_at_formatted']

    def get_created_at_formatted(self, obj):
        if not obj.created_at:
            return ""
        from django.utils import timezone
        now = timezone.now()
        diff = (now - obj.created_at).total_seconds()
        if diff < 60:
            return "Just now"
        elif diff < 3600:
            return f"{int(diff // 60)}m ago"
        elif diff < 86400:
            return f"{int(diff // 3600)}h ago"
        else:
            return obj.created_at.strftime("%b %d, %Y at %I:%M %p")

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
