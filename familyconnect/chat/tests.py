from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from chat.models import Conversation, Message, UserConversation

User = get_user_model()

class MessageViewSetTestCase(APITestCase):
    def setUp(self):
        # Create users
        self.user_participant_1 = User.objects.create_user(
            username="participant1",
            email="p1@example.com",
            password="testpassword123"
        )
        self.user_participant_2 = User.objects.create_user(
            username="participant2",
            email="p2@example.com",
            password="testpassword123"
        )
        self.user_non_participant = User.objects.create_user(
            username="nonparticipant",
            email="np@example.com",
            password="testpassword123"
        )

        # Create private conversation
        self.conversation = Conversation.objects.create(is_group=False)
        
        # Add participants
        UserConversation.objects.create(user=self.user_participant_1, conversation=self.conversation)
        UserConversation.objects.create(user=self.user_participant_2, conversation=self.conversation)

        self.messages_url = reverse('message-list')

    def test_participant_can_create_message(self):
        self.client.force_authenticate(user=self.user_participant_1)
        data = {
            'conversation': self.conversation.id,
            'content': 'Hello from participant 1',
            'message_type': 'TEXT'
        }
        response = self.client.post(self.messages_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Message.objects.filter(conversation=self.conversation).count(), 1)
        
        # Verify unread count updated for participant 2
        user_conv2 = UserConversation.objects.get(user=self.user_participant_2, conversation=self.conversation)
        self.assertEqual(user_conv2.unread_count, 1)

        # Verify unread count remains 0 for participant 1 (sender)
        user_conv1 = UserConversation.objects.get(user=self.user_participant_1, conversation=self.conversation)
        self.assertEqual(user_conv1.unread_count, 0)

    def test_non_participant_cannot_create_message(self):
        self.client.force_authenticate(user=self.user_non_participant)
        data = {
            'conversation': self.conversation.id,
            'content': 'Attempt to send from non-participant',
            'message_type': 'TEXT'
        }
        response = self.client.post(self.messages_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(Message.objects.filter(conversation=self.conversation).count(), 0)
