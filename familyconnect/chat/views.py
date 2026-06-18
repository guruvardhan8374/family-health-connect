from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser
from django.utils import timezone
from django.conf import settings
from django.db.models import Max
from google import genai
from google.genai import types
import os

from .models import Conversation, Message, UserConversation, Story
from .serializers import (
    ConversationSerializer, MessageSerializer, StorySerializer, 
    CreateConversationSerializer, CreateGroupSerializer
)
from .permissions import IsConversationParticipant
from .services import get_or_create_private_conversation, create_family_group_chat
from users.models import CustomUser
from family.models import FamilyGroup, FamilyMembership

class ConversationViewSet(viewsets.ModelViewSet):
    serializer_class = ConversationSerializer
    permission_classes = [permissions.IsAuthenticated, IsConversationParticipant]
    pagination_class = None

    def get_queryset(self):
        # Annotate with last message timestamp to sort active chats to top
        return Conversation.objects.filter(
            participants=self.request.user
        ).annotate(
            last_message_time=Max('messages__timestamp')
        ).order_by('-last_message_time', '-created_at')

    @action(detail=False, methods=['post'], url_path='private')
    def create_private_conversation(self, request):
        serializer = CreateConversationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        recipient_id = serializer.validated_data['recipient_id']
        try:
            recipient = CustomUser.objects.get(id=recipient_id)
        except CustomUser.DoesNotExist:
            return Response({"error": "Recipient user not found"}, status=status.HTTP_404_NOT_FOUND)
            
        try:
            conversation = get_or_create_private_conversation(request.user, recipient)
            return Response(ConversationSerializer(conversation, context={'request': request}).data, status=status.HTTP_201_CREATED)
        except ValueError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['post'], url_path='group')
    def create_group_conversation(self, request):
        serializer = CreateGroupSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        family_group_id = serializer.validated_data['family_group_id']
        try:
            family_group = FamilyGroup.objects.get(id=family_group_id)
        except FamilyGroup.DoesNotExist:
            return Response({"error": "Family group not found"}, status=status.HTTP_404_NOT_FOUND)
            
        # Check if user is approved member of the family
        is_member = FamilyMembership.objects.filter(user=request.user, family_group=family_group, is_approved=True).exists()
        if not is_member:
            return Response({"error": "You must be an approved family member to create this chat"}, status=status.HTTP_403_FORBIDDEN)
            
        conversation = create_family_group_chat(family_group)
        if serializer.validated_data.get('name'):
            conversation.name = serializer.validated_data['name']
        if serializer.validated_data.get('description'):
            conversation.description = serializer.validated_data['description']
        conversation.save()
        
        return Response(ConversationSerializer(conversation, context={'request': request}).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def pin(self, request, pk=None):
        conversation = self.get_object()
        user_conv, created = UserConversation.objects.get_or_create(user=request.user, conversation=conversation)
        user_conv.is_pinned = not user_conv.is_pinned
        user_conv.save()
        return Response({'status': 'success', 'is_pinned': user_conv.is_pinned})

    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        conversation = self.get_object()
        user_conv, created = UserConversation.objects.get_or_create(user=request.user, conversation=conversation)
        user_conv.is_pinned = False
        user_conv.is_archived = not user_conv.is_archived
        user_conv.save()
        return Response({'status': 'success', 'is_archived': user_conv.is_archived})

class MessageViewSet(viewsets.ModelViewSet):
    serializer_class = MessageSerializer
    permission_classes = [permissions.IsAuthenticated, IsConversationParticipant]
    search_fields = ['content']
    pagination_class = None

    def get_queryset(self):
        conversation_id = self.request.query_params.get('conversation')
        if conversation_id:
            # Check if user is participant of conversation_id
            is_member = UserConversation.objects.filter(user=self.request.user, conversation_id=conversation_id).exists()
            if not is_member:
                return Message.objects.none()
            return Message.objects.filter(conversation_id=conversation_id).order_by('-timestamp')
        return Message.objects.none()

    def perform_create(self, serializer):
        serializer.save(sender=self.request.user)

    @action(detail=False, methods=['post'], url_path='mark-read')
    def mark_read(self, request):
        conversation_id = request.data.get('conversation')
        if not conversation_id:
            return Response({"error": "conversation parameter is required"}, status=status.HTTP_400_BAD_REQUEST)
            
        UserConversation.objects.filter(user=request.user, conversation_id=conversation_id).update(unread_count=0)
        Message.objects.filter(conversation_id=conversation_id).exclude(sender=request.user).update(is_read=True, status='READ')
        return Response({"status": "messages marked as read"})

class MediaUploadView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, *args, **kwargs):
        file_obj = request.data.get('file')
        if not file_obj:
            return Response({'error': 'No file uploaded'}, status=status.HTTP_400_BAD_REQUEST)
        
        media_path = os.path.join(settings.MEDIA_ROOT, 'chat_media', file_obj.name)
        os.makedirs(os.path.dirname(media_path), exist_ok=True)
        
        with open(media_path, 'wb+') as destination:
            for chunk in file_obj.chunks():
                destination.write(chunk)
        
        file_url = request.build_absolute_uri(settings.MEDIA_URL + 'chat_media/' + file_obj.name)
        return Response({'url': file_url}, status=status.HTTP_201_CREATED)

class StoryViewSet(viewsets.ModelViewSet):
    serializer_class = StorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Show stories that are still active (within 24 hours)
        return Story.objects.filter(expires_at__gt=timezone.now()).order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=True, methods=['post'])
    def mark_viewed(self, request, pk=None):
        story = self.get_object()
        story.viewers.add(request.user)
        return Response({'status': 'viewed'})

class AIAssistantView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        prompt = request.data.get('prompt')
        context_type = request.data.get('context_type', 'HEALTH')
        
        if not prompt:
            return Response({'error': 'No prompt provided'}, status=status.HTTP_400_BAD_REQUEST)

        # Fallback rule-based system if API key is not configured
        if not settings.GEMINI_API_KEY:
            return self.get_rule_based_response(prompt, context_type)

        try:
            client = genai.Client(api_key=settings.GEMINI_API_KEY)

            system_instruction = "You are a helpful family health assistant. "
            if context_type == 'HEALTH':
                system_instruction += "Analyze the following health data and provide a concise, reassuring summary for family members. Do not give medical advice, but highlight if values are outside normal ranges."
            else:
                system_instruction += "Summarize the family conversation and highlight key action items or updates."

            response = client.models.generate_content(
                model='gemini-2.5-flash',
                contents=f"{system_instruction}\n\nUser Input: {prompt}"
            )
            return Response({'analysis': response.text}, status=status.HTTP_200_OK)
        except Exception as e:
            # On Google API or client failures, transparently fallback to rule-based insights
            return self.get_rule_based_response(prompt, context_type, api_error=str(e))

    def get_rule_based_response(self, prompt, context_type, api_error=None):
        if settings.GEMINI_API_KEY:
            try:
                client = genai.Client(api_key=settings.GEMINI_API_KEY)

                if context_type == 'HEALTH':
                    full_prompt = f"""
You are an intelligent AI assistant for Family Health Connect.

Rules:
- Answer health questions with health guidance.
- Give short and clear answers unless detailed explanation is requested.
- Provide hydration, sleep, exercise, and wellness suggestions only when health-related.
- If user asks "in one line", answer in one line only.

User question:
{prompt}
"""
                else:
                    full_prompt = f"""
You are an intelligent AI assistant.

Rules:
- Answer general questions normally and briefly.
- Keep answers short, simple, and human-friendly.
- Do NOT give health advice unless the question is health-related.
- If user asks "in one line", answer in one line only.
- Only give detailed answers if user asks for details.

User question:
{prompt}
"""

                response = client.models.generate_content(
                    model='gemini-2.5-flash',
                    contents=full_prompt
                )

                return Response(
                    {
                        'analysis': response.text,
                        'fallback': False,
                        'api_error': None
                    },
                    status=status.HTTP_200_OK
                )
            except Exception as e:
                api_error = str(e)

        # Local rule-based/heuristic fallback if API key is empty/invalid or Gemini API calls fail
        import re
        prompt_lower = prompt.lower()
        
        def has_word(keywords):
            return any(re.search(r'\b' + re.escape(kw), prompt_lower) for kw in keywords)

        if context_type == 'HEALTH':
            if has_word(['sleep', 'insomnia', 'tired', 'wake', 'bed']):
                analysis = "Aim for 7-8 hours of quality sleep tonight. Try keeping a regular sleep schedule, avoiding screens before bed, and keeping your room quiet and dark."
            elif has_word(['water', 'hydrate', 'hydration', 'drink', 'thirsty']):
                analysis = "Aim to drink at least 8-10 glasses (about 2-2.5 liters) of water daily to stay hydrated and support energy levels."
            elif has_word(['exercise', 'step', 'walk', 'run', 'activity', 'fit', 'sport']):
                analysis = "Try incorporating at least 30 minutes of moderate exercise, such as brisk walking, most days of the week to support cardiovascular health."
            elif has_word(['diet', 'food', 'eat', 'nutrition', 'weight', 'bmi', 'calorie']):
                analysis = "Maintain a balanced diet rich in vegetables, fruits, lean proteins, and whole grains, while limiting processed foods, sugar, and excess salt."
            elif has_word(['heart', 'bp', 'blood pressure', 'pulse', 'vital']):
                analysis = "A normal resting heart rate is typically 60-100 bpm, and blood pressure should ideally be below 120/80 mmHg. Consult a doctor for persistent variations."
            elif has_word(['stress', 'anxious', 'calm', 'relax', 'mental']):
                analysis = "Manage stress through deep breathing exercises, mindfulness, light exercise, and connecting with family. Seek professional support if needed."
            else:
                analysis = "I'm monitoring your family's health queries. You can ask me about sleep, hydration, exercise, diet, heart rate, or stress management."
        else:
            if has_word(['hi', 'hello', 'hey', 'greetings']):
                analysis = "Hello! I am your Family Health AI Assistant. How can I help you and your family today?"
            elif has_word(['summary', 'conversation', 'chat', 'discuss']):
                analysis = "Based on the recent family conversation, everyone seems to be staying active. Keep sharing updates and supporting each other!"
            else:
                analysis = "I am your Family Health Assistant. I can help you summarize family health updates or answer questions about wellness and vitals."

        return Response(
            {
                'analysis': analysis,
                'fallback': True,
                'api_error': api_error
            },
            status=status.HTTP_200_OK
        )