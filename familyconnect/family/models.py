from django.db import models
from django.conf import settings

class FamilyGroup(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True, null=True)
    family_code = models.CharField(max_length=12, unique=True, blank=True, null=True)
    max_members = models.PositiveIntegerField(default=10)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='created_families')

    def __str__(self):
        return self.name

class FamilyMembership(models.Model):
    RELATION_CHOICES = (
        ('PARENT', 'Parent'),
        ('CHILD', 'Child'),
        ('ELDER', 'Elder'),
        ('SPOUSE', 'Spouse'),
        ('OTHER', 'Other'),
    )
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='family_memberships')
    family_group = models.ForeignKey(FamilyGroup, on_delete=models.CASCADE, related_name='memberships')
    joined_at = models.DateTimeField(auto_now_add=True)
    is_admin = models.BooleanField(default=False)
    is_approved = models.BooleanField(default=True) # Default True for creator/invited, but False for request to join
    label = models.CharField(max_length=20, choices=RELATION_CHOICES, default='OTHER')

    class Meta:
        unique_together = ('user', 'family_group')

    def __str__(self):
        return f"{self.user.username} ({self.label}) in {self.family_group.name}"

class SafeZone(models.Model):
    family_group = models.ForeignKey(FamilyGroup, on_delete=models.CASCADE, related_name='safe_zones')
    name = models.CharField(max_length=100) # e.g., "Home", "School", "Work"
    latitude = models.FloatField()
    longitude = models.FloatField()
    radius_meters = models.FloatField(default=100.0)
    
    def __str__(self):
        return f"{self.name} for {self.family_group.name}"

class FamilyInvitation(models.Model):
    STATUS_CHOICES = (
        ('PENDING', 'Pending'),
        ('ACCEPTED', 'Accepted'),
        ('REJECTED', 'Rejected'),
        ('EXPIRED', 'Expired'),
    )
    family_group = models.ForeignKey(FamilyGroup, on_delete=models.CASCADE, related_name='invitations')
    invited_email = models.EmailField()
    invited_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='sent_invitations')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    token = models.CharField(max_length=64, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    def __str__(self):
        return f"Invite for {self.invited_email} to {self.family_group.name}"
