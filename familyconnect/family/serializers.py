from rest_framework import serializers
from .models import FamilyGroup, FamilyMembership, SafeZone, FamilyInvitation
from users.serializers import UserSerializer

class FamilyGroupSerializer(serializers.ModelSerializer):
    member_count = serializers.IntegerField(read_only=True)
    created_by_details = UserSerializer(source='created_by', read_only=True)

    class Meta:
        model = FamilyGroup
        fields = ['id', 'name', 'description', 'family_code', 'max_members', 'created_at', 'created_by', 'created_by_details', 'member_count']
        read_only_fields = ['id', 'family_code', 'created_at', 'created_by']

class FamilyMembershipSerializer(serializers.ModelSerializer):
    user_details = UserSerializer(source='user', read_only=True)
    latest_location = serializers.SerializerMethodField()
    latest_health_record = serializers.SerializerMethodField()

    class Meta:
        model = FamilyMembership
        fields = ['id', 'user', 'family_group', 'joined_at', 'is_admin',
                  'user_details', 'label', 'status', 'is_approved', 'latest_location', 'latest_health_record']
        read_only_fields = ['id', 'joined_at']

    def get_latest_health_record(self, obj):
        try:
            hr = None
            steps = None
            spo2 = None
            sleep = None
            recorded_date = None

            # 1. Check HealthSnapshot (where mobile Health Connect & Google Fit syncs live)
            from health.models import HealthSnapshot
            snapshot = HealthSnapshot.objects.filter(user=obj.user).order_by('-recorded_at').first()
            if snapshot:
                hr = snapshot.heart_rate
                steps = snapshot.steps
                spo2 = snapshot.spo2
                sleep = snapshot.sleep_hours
                recorded_date = snapshot.recorded_at.isoformat() if snapshot.recorded_at else None

            # 2. Check HealthRecord (fallback / manual records app)
            try:
                from family_health_records_app.models import HealthRecord
                record = HealthRecord.objects.filter(user=obj.user).order_by('-recorded_date', '-created_at').first()
                if record:
                    if hr is None or hr == 0:
                        hr = record.heart_rate
                    if steps is None or steps == 0:
                        steps = record.steps
                    if spo2 is None or spo2 == 0:
                        spo2 = record.oxygen_level
                    if sleep is None or sleep == 0:
                        sleep = record.sleep_hours
                    if not recorded_date and record.recorded_date:
                        recorded_date = record.recorded_date.isoformat()
            except Exception:
                pass

            if hr is not None or steps is not None or spo2 is not None or sleep is not None:
                return {
                    'heart_rate': hr or 0,
                    'steps': steps or 0,
                    'oxygen_level': spo2 or 0.0,
                    'spo2': spo2 or 0.0,
                    'sleep_hours': sleep or 0.0,
                    'recorded_date': recorded_date,
                }
        except Exception:
            pass
        return None

    def get_latest_location(self, obj):
        try:
            from django.utils import timezone
            is_sharing = True
            try:
                if hasattr(obj.user, 'privacy_settings'):
                    is_sharing = obj.user.privacy_settings.location_sharing
            except Exception:
                pass

            latest = obj.user.location_history.order_by('-timestamp').first()
            if latest:
                now = timezone.now()
                diff_seconds = (now - latest.timestamp).total_seconds()
                is_online = (diff_seconds < 45) and is_sharing

                if not is_sharing:
                    last_seen_str = "Sharing disabled"
                elif diff_seconds < 60:
                    last_seen_str = "Just now"
                elif diff_seconds < 3600:
                    mins = int(diff_seconds // 60)
                    last_seen_str = f"{mins}m ago"
                else:
                    last_seen_str = latest.timestamp.strftime("Last seen at %I:%M %p")

                return {
                    'latitude': latest.latitude,
                    'longitude': latest.longitude,
                    'speed': getattr(latest, 'speed', 0.0) or 0.0,
                    'battery_level': getattr(latest, 'battery_level', 100) or 100,
                    'is_moving': getattr(latest, 'is_moving', False),
                    'timestamp': latest.timestamp.isoformat(),
                    'is_online': is_online,
                    'is_sharing_enabled': is_sharing,
                    'is_last_known': not is_online,
                    'last_seen_formatted': last_seen_str,
                }
        except Exception:
            pass
        return None

class FamilyGroupDetailSerializer(serializers.ModelSerializer):
    memberships = FamilyMembershipSerializer(many=True, read_only=True)
    created_by_details = UserSerializer(source='created_by', read_only=True)
    
    class Meta:
        model = FamilyGroup
        fields = ['id', 'name', 'description', 'family_code', 'max_members', 'created_at', 'created_by', 'created_by_details', 'memberships']
        read_only_fields = ['id', 'family_code', 'created_at', 'created_by']

class SafeZoneSerializer(serializers.ModelSerializer):
    class Meta:
        model = SafeZone
        fields = '__all__'

class FamilyInvitationSerializer(serializers.ModelSerializer):
    invited_by_details = UserSerializer(source='invited_by', read_only=True)
    family_group_name = serializers.CharField(source='family_group.name', read_only=True)

    class Meta:
        model = FamilyInvitation
        fields = ['id', 'family_group', 'family_group_name', 'invited_email', 'invited_by', 'invited_by_details', 'status', 'token', 'created_at', 'expires_at']
        read_only_fields = ['id', 'status', 'token', 'created_at', 'expires_at', 'invited_by']
