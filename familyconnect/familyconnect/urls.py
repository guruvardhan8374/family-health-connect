"""
URL configuration for familyconnect project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from users.views import SecureTokenObtainPairView
from rest_framework_simplejwt.views import TokenRefreshView
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
    SpectacularRedocView,
)

def health_check(request):
    return JsonResponse({"status": "ok"})

from health.views import HealthSyncAPIView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/health/', health_check, name='health-check'),
    path('api/health-sync', HealthSyncAPIView.as_view(), name='api-health-sync'),
    path('api/health-sync/', HealthSyncAPIView.as_view(), name='api-health-sync-slash'),
    path('api/token/', SecureTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/v1/token/', SecureTokenObtainPairView.as_view(), name='token_obtain_pair_v1'),
    path('api/v1/token/refresh/', TokenRefreshView.as_view(), name='token_refresh_v1'),

    # API schema & docs
    path('api/v1/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/v1/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/v1/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),

    # App URLs
    path('api/v1/users/', include('users.urls')),
    path('api/v1/family/', include('family.urls')),
    path('api/v1/health/', include('health.urls')),
    path('api/v1/emergency/', include('emergency.urls')),
    path('api/v1/chat/', include('chat.urls')),
    path('api/v1/notifications/', include('notifications.urls')),
    path('api/v1/iot/', include('iot.urls')),
    path('api/v1/admin/', include('admin_api.urls')),
    path('api/v1/settings/', include('settings_app.urls')),
    path('api/v1/', include('family_health_records_app.urls')),
    path('api/v1/sync/', include('sync.urls')),
]
from django.conf import settings
from django.conf.urls.static import static

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

