from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import FamilyGroupViewSet, FamilyMembershipViewSet, SafeZoneViewSet, FamilyInvitationViewSet

router = DefaultRouter()
router.register(r'groups', FamilyGroupViewSet, basename='familygroup')
router.register(r'members', FamilyMembershipViewSet, basename='familymembership')
router.register(r'safe-zones', SafeZoneViewSet, basename='safezone')
router.register(r'invitations', FamilyInvitationViewSet, basename='familyinvitation')

urlpatterns = [
    path('', include(router.urls)),
]
