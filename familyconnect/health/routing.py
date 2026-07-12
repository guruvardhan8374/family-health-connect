from django.urls import re_path
from .consumers import HealthConsumer

websocket_urlpatterns = [
    re_path(r'^ws/health/$', HealthConsumer.as_asgi()),
]
