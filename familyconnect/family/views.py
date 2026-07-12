from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.db.models import Count
from django.utils import timezone
from datetime import timedelta
import hashlib
import secrets

from .models import FamilyGroup, FamilyMembership, SafeZone, FamilyInvitation
from .serializers import (
    FamilyGroupSerializer, FamilyGroupDetailSerializer, 
    FamilyMembershipSerializer, SafeZoneSerializer, FamilyInvitationSerializer
)
from .permissions import IsFamilyMember, IsFamilyAdmin
from .services import generate_family_code, send_invitation_email, get_family_summary
from users.models import CustomUser

class FamilyGroupViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_serializer_class(self):
        if self.action in ['retrieve', 'update', 'partial_update']:
            return FamilyGroupDetailSerializer
        return FamilyGroupSerializer

    def get_queryset(self):
        # Users can only see family groups they are a member of
        return FamilyGroup.objects.filter(
            memberships__user=self.request.user,
            memberships__is_approved=True
        ).annotate(member_count=Count('memberships')).distinct().order_by('-created_at')

    def perform_create(self, serializer):
        import logging
        logger = logging.getLogger(__name__)

        code = generate_family_code()
        while FamilyGroup.objects.filter(family_code=code).exists():
            code = generate_family_code()
        group = serializer.save(created_by=self.request.user, family_code=code)

        # Create the creator's membership as Family Head (admin + approved).
        # Use get_or_create so that a double-submit or a retry after token refresh
        # does not raise IntegrityError on the unique_together(user, family_group)
        # constraint and falsely tell the user "already exists".
        try:
            membership, _ = FamilyMembership.objects.get_or_create(
                user=self.request.user,
                family_group=group,
                defaults={
                    'is_admin': True,
                    'is_approved': True,
                    'label': 'HEAD',
                    'status': 'ACTIVE',
                }
            )
            # Ensure the creator always ends up as admin, even if row existed
            if not membership.is_admin or not membership.is_approved:
                membership.is_admin = True
                membership.is_approved = True
                membership.label = 'HEAD'
                membership.status = 'ACTIVE'
                membership.save(update_fields=['is_admin', 'is_approved', 'label', 'status'])
        except Exception as e:
            logger.error(f"Failed to create HEAD membership for user {self.request.user.id}: {e}")

        # Promote user's system role to HEAD if they are currently a plain MEMBER
        try:
            user = self.request.user
            if user.role == 'MEMBER':
                user.role = 'HEAD'
                user.save(update_fields=['role'])
        except Exception as e:
            logger.error(f"Failed to update user role to HEAD: {e}")

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        # Re-fetch with annotation so member_count is always present
        group = FamilyGroup.objects.annotate(
            member_count=Count('memberships')
        ).get(pk=serializer.instance.pk)
        response_serializer = self.get_serializer(group)
        return Response({
            'success': True,
            'message': 'Family Circle created successfully!',
            **response_serializer.data
        }, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'], url_path='join-by-code')
    def join_by_code(self, request):
        code = request.data.get('family_code')
        label = request.data.get('label', 'OTHER')
        if not code:
            return Response({"error": "Family code is required"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            group = FamilyGroup.objects.annotate(member_count=Count('memberships')).get(family_code=code)
        except FamilyGroup.DoesNotExist:
            return Response({"error": "Invalid family code"}, status=status.HTTP_400_BAD_REQUEST)

        if group.member_count >= group.max_members:
            return Response({"error": "Family group has reached the maximum members limit"}, status=status.HTTP_400_BAD_REQUEST)

        membership, created = FamilyMembership.objects.get_or_create(
            user=request.user,
            family_group=group,
            defaults={
                'is_admin': False,
                'is_approved': False, # Needs admin approval to join by code
                'label': label
            }
        )

        if not created:
            if membership.is_approved:
                return Response({"message": "You are already a member of this family group."}, status=status.HTTP_200_OK)
            return Response({"message": "Your join request is already pending admin approval."}, status=status.HTTP_200_OK)

        # Notify family admins of the join request
        try:
            from notifications.services import create_notification
            admins = FamilyMembership.objects.filter(family_group=group, is_admin=True, is_approved=True)
            for admin in admins:
                create_notification(
                    user=admin.user,
                    type='SYSTEM',
                    title='New Join Request',
                    message=f"{request.user.username} requested to join '{group.name}' using code.",
                    priority='NORMAL'
                )
        except Exception:
            pass

        return Response({
            "message": f"Join request submitted successfully! An admin of '{group.name}' must approve your request.",
            "membership": FamilyMembershipSerializer(membership).data
        }, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], url_path='invite')
    def invite_member(self, request, pk=None):
        group = self.get_object()
        
        # Check if user is admin
        is_admin = FamilyMembership.objects.filter(user=request.user, family_group=group, is_admin=True, is_approved=True).exists()
        if not is_admin:
            return Response({"error": "Only family admins can invite members"}, status=status.HTTP_403_FORBIDDEN)

        email = request.data.get('email')
        label = request.data.get('label', 'OTHER')
        if not email:
            return Response({"error": "Email is required"}, status=status.HTTP_400_BAD_REQUEST)

        token = hashlib.sha256(secrets.token_bytes(32)).hexdigest()
        expires_at = timezone.now() + timedelta(days=7)

        invitation, created = FamilyInvitation.objects.update_or_create(
            family_group=group,
            invited_email=email,
            defaults={
                'invited_by': request.user,
                'status': 'PENDING',
                'token': token,
                'expires_at': expires_at
            }
        )

        send_invitation_email(invitation)

        # If user already exists in system, auto-notify them
        try:
            target_user = CustomUser.objects.get(email=email)
            from notifications.services import create_notification
            create_notification(
                user=target_user,
                type='SYSTEM',
                title='Family Invitation',
                message=f"You have been invited by {request.user.username} to join '{group.name}'.",
                priority='HIGH',
                data={'family_group_id': group.id, 'invite_token': token}
            )
        except CustomUser.DoesNotExist:
            pass

        return Response({
            "message": f"Invitation successfully sent to {email}",
            "invitation": FamilyInvitationSerializer(invitation).data
        }, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['get'])
    def summary(self, request, pk=None):
        group = self.get_object()
        return Response(get_family_summary(group))

class FamilyMembershipViewSet(viewsets.ModelViewSet):
    serializer_class = FamilyMembershipSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['is_approved', 'is_admin', 'label']
    pagination_class = None

    def get_queryset(self):
        groups = FamilyGroup.objects.filter(memberships__user=self.request.user, memberships__is_approved=True)
        return FamilyMembership.objects.filter(family_group__in=groups).order_by('-joined_at')

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        membership = self.get_object()
        
        # Only admins of this specific family group can approve
        is_admin = FamilyMembership.objects.filter(user=request.user, family_group=membership.family_group, is_admin=True, is_approved=True).exists()
        if not is_admin:
            return Response({"error": "Only family admins can approve members"}, status=status.HTTP_403_FORBIDDEN)
        
        membership.is_approved = True
        membership.save()

        # Notify the user their request was approved
        from notifications.services import create_notification
        create_notification(
            user=membership.user,
            type='SYSTEM',
            title='Membership Approved',
            message=f"Your request to join the family group '{membership.family_group.name}' has been approved!",
            priority='HIGH'
        )

        return Response({"status": "member approved", "membership": FamilyMembershipSerializer(membership).data})

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        membership = self.get_object()
        
        is_admin = FamilyMembership.objects.filter(user=request.user, family_group=membership.family_group, is_admin=True, is_approved=True).exists()
        if not is_admin:
            return Response({"error": "Only family admins can reject requests"}, status=status.HTTP_403_FORBIDDEN)
        
        if membership.is_approved:
            return Response({"error": "Cannot reject an already approved membership"}, status=status.HTTP_400_BAD_REQUEST)

        membership.delete()
        return Response({"status": "member request rejected"})

    @action(detail=True, methods=['post'], url_path='promote-admin')
    def promote_admin(self, request, pk=None):
        membership = self.get_object()
        
        is_admin = FamilyMembership.objects.filter(user=request.user, family_group=membership.family_group, is_admin=True, is_approved=True).exists()
        if not is_admin:
            return Response({"error": "Only family admins can promote members"}, status=status.HTTP_403_FORBIDDEN)
        
        membership.is_admin = True
        membership.save()
        return Response({"status": "member promoted to admin"})

    @action(detail=True, methods=['post'], url_path='demote-admin')
    def demote_admin(self, request, pk=None):
        membership = self.get_object()
        
        is_admin = FamilyMembership.objects.filter(user=request.user, family_group=membership.family_group, is_admin=True, is_approved=True).exists()
        if not is_admin:
            return Response({"error": "Only family admins can demote members"}, status=status.HTTP_403_FORBIDDEN)
        
        if membership.family_group.created_by == membership.user:
            return Response({"error": "Cannot demote the creator of the family group"}, status=status.HTTP_400_BAD_REQUEST)
            
        membership.is_admin = False
        membership.save()
        return Response({"status": "member demoted from admin"})

class SafeZoneViewSet(viewsets.ModelViewSet):
    serializer_class = SafeZoneSerializer
    permission_classes = [permissions.IsAuthenticated, IsFamilyMember]

    def get_queryset(self):
        groups = FamilyGroup.objects.filter(memberships__user=self.request.user, memberships__is_approved=True)
        return SafeZone.objects.filter(family_group__in=groups)

class FamilyInvitationViewSet(viewsets.ModelViewSet):
    serializer_class = FamilyInvitationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return FamilyInvitation.objects.filter(
            family_group__memberships__user=self.request.user,
            family_group__memberships__is_admin=True
        ).distinct().order_by('-created_at')

    def perform_create(self, serializer):
        # ViewSet creates custom invites inside the `invite_member` action of FamilyGroupViewSet
        pass

    @action(detail=False, methods=['post'], url_path='accept', permission_classes=[permissions.IsAuthenticated])
    def accept_invitation(self, request):
        token = request.data.get('token')
        label = request.data.get('label', 'OTHER')
        if not token:
            return Response({"error": "Token is required"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            invitation = FamilyInvitation.objects.get(token=token, status='PENDING')
        except FamilyInvitation.DoesNotExist:
            return Response({"error": "Invalid or already processed invitation token"}, status=status.HTTP_400_BAD_REQUEST)

        if timezone.now() > invitation.expires_at:
            invitation.status = 'EXPIRED'
            invitation.save()
            return Response({"error": "Invitation has expired"}, status=status.HTTP_400_BAD_REQUEST)

        # Create membership
        membership, created = FamilyMembership.objects.get_or_create(
            user=request.user,
            family_group=invitation.family_group,
            defaults={
                'is_admin': False,
                'is_approved': True, # Pre-approved because they were invited by email
                'label': label
            }
        )

        invitation.status = 'ACCEPTED'
        invitation.save()

        return Response({
            "message": "Invitation accepted successfully",
            "membership": FamilyMembershipSerializer(membership).data
        }, status=status.HTTP_200_OK)
