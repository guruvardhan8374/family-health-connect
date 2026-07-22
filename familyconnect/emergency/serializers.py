from rest_framework import serializers
from .models import EmergencyContact, SOSAlert, NearbyHospital

class EmergencyContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyContact
        fields = ['id', 'user', 'name', 'relation', 'phone_number']
        read_only_fields = ['id', 'user']

class SOSAlertSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    family_name = serializers.SerializerMethodField()
    google_maps_link = serializers.SerializerMethodField()
    emergency_type = serializers.SerializerMethodField()
    
    class Meta:
        model = SOSAlert
        fields = [
            'id', 'user', 'username', 'family_name', 'emergency_type',
            'location_lat', 'location_lng', 'google_maps_link',
            'message', 'status', 'is_resolved', 'triggered_at',
            'resolved_at', 'vitals_snapshot'
        ]
        read_only_fields = ['id', 'user', 'triggered_at', 'vitals_snapshot']

    def get_family_name(self, obj):
        from family.models import FamilyMembership
        memberships = FamilyMembership.objects.filter(user=obj.user, is_approved=True)
        if memberships.exists():
            return ", ".join([m.family_group.name for m in memberships if m.family_group])
        return "No Family Circle"

    def get_google_maps_link(self, obj):
        if obj.location_lat is not None and obj.location_lng is not None:
            return f"https://www.google.com/maps/search/?api=1&query={obj.location_lat},{obj.location_lng}"
        return ""

    def get_emergency_type(self, obj):
        msg = (obj.message or "").lower()
        if "heart" in msg or "vital" in msg:
            return "Cardiovascular / Vitals Alert"
        if "fall" in msg or "mobility" in msg:
            return "Fall Detected / Mobility Alert"
        if "accident" in msg or "car" in msg:
            return "Accident / Trauma Alert"
        return "SOS Distress Alert"

class NearbyHospitalSerializer(serializers.ModelSerializer):
    class Meta:
        model = NearbyHospital
        fields = '__all__'
