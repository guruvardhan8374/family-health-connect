from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser
from django.utils import timezone
from django.conf import settings
from django.db.models import Max
import os

try:
    from google import genai as google_genai
    from google.genai import types as genai_types
    GENAI_AVAILABLE = True
except ImportError:
    try:
        import google.generativeai as genai_legacy
        GENAI_AVAILABLE = True
        google_genai = None
    except ImportError:
        GENAI_AVAILABLE = False
        google_genai = None
        genai_legacy = None

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

    def _call_gemini(self, prompt):
        """
        Try new google-genai SDK first, fall back to old google-generativeai.
        Returns the response text or raises an exception.
        """
        api_key = settings.GEMINI_API_KEY
        if not api_key:
            raise ValueError("GEMINI_API_KEY is not configured.")

        # New SDK (google-genai)
        if google_genai is not None:
            client = google_genai.Client(api_key=api_key)
            response = client.models.generate_content(
                model='gemini-2.0-flash',
                contents=prompt
            )
            return response.text

        # Legacy SDK (google-generativeai)
        if genai_legacy is not None:
            genai_legacy.configure(api_key=api_key)
            model = genai_legacy.GenerativeModel('gemini-1.5-flash')
            response = model.generate_content(prompt)
            return response.text

        raise ImportError("No Gemini SDK available. Install google-genai.")

    def post(self, request, *args, **kwargs):
        prompt = request.data.get('prompt', '').strip()
        context_type = request.data.get('context_type', 'HEALTH')

        if not prompt:
            return Response({'error': 'No prompt provided.'}, status=status.HTTP_400_BAD_REQUEST)

        if not settings.GEMINI_API_KEY or not GENAI_AVAILABLE:
            return self._rule_based(prompt, context_type,
                                    api_error="GEMINI_API_KEY not set or SDK not installed.")

        # Build system-aware prompt
        if context_type == 'HEALTH':
            system = (
                "You are a helpful, concise family health AI assistant. "
                "Answer health questions clearly. Do NOT give medical diagnoses. "
                "Highlight if values are outside normal ranges. Keep responses under 150 words."
            )
        else:
            system = (
                "You are a friendly family AI assistant. "
                "Answer questions briefly and clearly. "
                "Keep responses under 150 words."
            )

        full_prompt = f"{system}\n\nUser: {prompt}"

        try:
            text = self._call_gemini(full_prompt)
            return Response({
                'analysis': text,
                'fallback': False,
                'api_error': None
            }, status=status.HTTP_200_OK)
        except Exception as e:
            import logging
            logging.getLogger(__name__).error(f"Gemini API error: {e}")
            return self._rule_based(prompt, context_type, api_error=str(e))

    def _rule_based(self, prompt, context_type, api_error=None):
        """Keyword-based fallback when Gemini is unavailable."""
        import re
        p = prompt.lower()

        def has(words):
            return any(re.search(r'\b' + re.escape(w), p) for w in words)

        if context_type == 'HEALTH':
            if has(['sleep', 'insomnia', 'tired', 'wake', 'bed']):
                text = "Aim for 7-8 hours of quality sleep. Keep a consistent schedule and avoid screens before bed."
            elif has(['water', 'hydrat', 'drink', 'thirsty']):
                text = "Drink 2-2.5 litres of water daily. Staying hydrated supports energy and focus."
            elif has(['exercise', 'step', 'walk', 'run', 'activity', 'fit']):
                text = "30 minutes of moderate exercise most days supports heart health and energy levels."
            elif has(['diet', 'food', 'eat', 'weight', 'bmi', 'calorie']):
                text = "A balanced diet of vegetables, lean protein, and whole grains keeps your family healthy."
            elif has(['heart', 'bp', 'blood pressure', 'pulse']):
                text = "Normal resting heart rate is 60-100 bpm. Ideal blood pressure is below 120/80 mmHg."
            elif has(['stress', 'anxious', 'calm', 'relax', 'mental']):
                text = "Deep breathing, light exercise, and family time help manage stress effectively."
            elif has(['fever', 'temperature', 'sick', 'ill']):
                text = "Normal temperature is 36.5-37.5°C. A fever above 38°C warrants rest and hydration."
            else:
                text = ("I can help with sleep, hydration, exercise, diet, heart rate, and stress. "
                        "Ask me anything about your family's wellness!")
        else:
            if has(['hi', 'hello', 'hey']):
                text = "Hello! I'm your Family Health AI. How can I help you today?"
            elif has(['summary', 'summarize', 'conversation']):
                text = "Your family has been active and engaged. Keep sharing updates and supporting each other!"
            elif has(['emergency', 'sos', 'help', 'urgent']):
                text = "If this is a medical emergency, please call emergency services (112 or 911) immediately."
            else:
                text = "I'm your Family Health Assistant. I can answer health questions or summarize family updates."

        return Response({
            'analysis': text,
            'fallback': True,
            'api_error': api_error
        }, status=status.HTTP_200_OK)