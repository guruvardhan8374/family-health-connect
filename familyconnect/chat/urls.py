from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'conversations', views.ConversationViewSet, basename='conversation')
router.register(r'messages', views.MessageViewSet, basename='message')
router.register(r'stories', views.StoryViewSet, basename='story')

urlpatterns = [
    path('', include(router.urls)),
    path('upload/', views.MediaUploadView.as_view(), name='media-upload'),
    path('ai-assistant/', views.AIAssistantView.as_view(), name='ai-assistant'),
]
