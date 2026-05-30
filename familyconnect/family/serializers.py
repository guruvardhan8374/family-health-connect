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
    
    class Meta:
        model = FamilyMembership
        fields = ['id', 'user', 'family_group', 'joined_at', 'is_admin', 'user_details', 'label', 'is_approved']
        read_only_fields = ['id', 'joined_at']

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
