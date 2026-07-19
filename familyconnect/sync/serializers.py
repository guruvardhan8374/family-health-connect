from rest_framework import serializers
from .models import AIAssistantHistory


class AIAssistantHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = AIAssistantHistory
        fields = ['id', 'role', 'content', 'created_at']
        read_only_fields = ['id', 'created_at']


class PendingMutationSerializer(serializers.Serializer):
    """Represents a single queued offline mutation from a client."""
    endpoint = serializers.CharField(max_length=255)
    method = serializers.ChoiceField(choices=['GET', 'POST', 'PUT', 'PATCH', 'DELETE'])
    payload = serializers.JSONField(default=dict)
    client_timestamp = serializers.DateTimeField(required=False)


class PendingSyncSerializer(serializers.Serializer):
    """Batch of pending offline mutations to replay."""
    mutations = PendingMutationSerializer(many=True)
