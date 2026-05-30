from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from .services import IoTDataSyncService
from .models import SyncHistory
from rest_framework import serializers

class SyncHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = SyncHistory
        fields = '__all__'

class IoTManualSyncView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        platform = request.data.get('platform', 'GOOGLE_FIT')
        success = IoTDataSyncService.sync_user_data(request.user, platform)
        
        if success:
            return Response({"message": f"Successfully synced data from {platform}"}, status=status.HTTP_200_OK)
        return Response({"error": "Sync failed"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class SyncStatusView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        history = SyncHistory.objects.filter(user=request.user).order_by('-last_sync')[:10]
        serializer = SyncHistorySerializer(history, many=True)
        return Response(serializer.data)
