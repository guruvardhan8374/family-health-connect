from rest_framework import serializers
from .models import EmergencyContact, SOSAlert, NearbyHospital

class EmergencyContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyContact
        fields = ['id', 'user', 'name', 'relation', 'phone_number']
        read_only_fields = ['id', 'user']

class SOSAlertSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    
    class Meta:
        model = SOSAlert
        fields = ['id', 'user', 'username', 'location_lat', 'location_lng', 'message', 'status', 'is_resolved', 'triggered_at', 'resolved_at', 'vitals_snapshot']
        read_only_fields = ['id', 'user', 'triggered_at', 'vitals_snapshot']

class NearbyHospitalSerializer(serializers.ModelSerializer):
    class Meta:
        model = NearbyHospital
        fields = '__all__'
