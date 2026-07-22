from django.db import models
from django.conf import settings
from family.models import FamilyGroup

class Conversation(models.Model):
    family_group = models.ForeignKey(FamilyGroup, on_delete=models.CASCADE, related_name='conversations', null=True, blank=True)
    participants = models.ManyToManyField(settings.AUTH_USER_MODEL, related_name='conversations', through='UserConversation')
    created_at = models.DateTimeField(auto_now_add=True)
    is_group = models.BooleanField(default=False)
    name = models.CharField(max_length=255, null=True, blank=True)
    description = models.TextField(null=True, blank=True)
    group_photo = models.URLField(null=True, blank=True)

    def __str__(self):
        return f"Conversation {self.id} (Group: {self.is_group})"

class UserConversation(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE)
    is_pinned = models.BooleanField(default=False)
    is_archived = models.BooleanField(default=False)
    unread_count = models.IntegerField(default=0)
    last_read_message = models.ForeignKey('Message', on_delete=models.SET_NULL, null=True, blank=True, related_name='+')
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'conversation')

class Message(models.Model):
    MESSAGE_TYPES = (
        ('TEXT', 'Text'),
        ('IMAGE', 'Image'),
        ('VIDEO', 'Video'),
        ('AUDIO', 'Audio'),
        ('DOCUMENT', 'Document'),
        ('HEALTH', 'Health Report'),
        ('SYSTEM', 'System Message'),
    )
    MESSAGE_STATUS = (
        ('SENT', 'Sent'),
        ('DELIVERED', 'Delivered'),
        ('READ', 'Read'),
    )

    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='sent_messages')
    content = models.TextField(blank=True, null=True)
    message_type = models.CharField(max_length=20, choices=MESSAGE_TYPES, default='TEXT')
    media_url = models.URLField(blank=True, null=True)
    health_data = models.JSONField(blank=True, null=True)
    reply_to = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='replies')
    timestamp = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=20, choices=MESSAGE_STATUS, default='SENT')
    is_read = models.BooleanField(default=False) # Keep for backward compatibility for now

    def __str__(self):
        return f"Message {self.id} by {self.sender.username}"

class CallHistory(models.Model):
    CALL_TYPES = (
        ('VOICE', 'Voice'),
        ('VIDEO', 'Video'),
    )
    CALL_STATUS = (
        ('MISSED', 'Missed'),
        ('COMPLETED', 'Completed'),
        ('REJECTED', 'Rejected'),
        ('ONGOING', 'Ongoing'),
    )

    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name='calls')
    caller = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='initiated_calls')
    receiver = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='received_calls', null=True, blank=True) # Null for group calls
    call_type = models.CharField(max_length=10, choices=CALL_TYPES, default='VIDEO')
    status = models.CharField(max_length=20, choices=CALL_STATUS, default='ONGOING')
    started_at = models.DateTimeField(auto_now_add=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    duration = models.IntegerField(default=0) # In seconds

    def __str__(self):
        return f"{self.call_type} Call - {self.status} at {self.started_at}"

class Story(models.Model):
    STORY_TYPES = (
        ('IMAGE', 'Image'),
        ('VIDEO', 'Video'),
        ('TEXT', 'Text'),
        ('HEALTH', 'Health Data'),
    )
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='stories')
    media_url = models.URLField(null=True, blank=True)
    content = models.TextField(blank=True, null=True)
    story_type = models.CharField(max_length=10, choices=STORY_TYPES, default='IMAGE')
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    viewers = models.ManyToManyField(settings.AUTH_USER_MODEL, related_name='viewed_stories', blank=True)

    def save(self, *args, **kwargs):
        if not self.expires_at:
            from django.utils import timezone
            import datetime
            self.expires_at = timezone.now() + datetime.timedelta(hours=24)
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Story by {self.user.username} at {self.created_at}"

class AIChatHistory(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='ai_chat_history')
    prompt = models.TextField()
    response = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"AI Chat for {self.user.username} at {self.created_at}"
