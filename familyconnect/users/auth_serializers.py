from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import authenticate
from django.contrib.auth import get_user_model

User = get_user_model()

class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        # Allow login with either username or email
        username_or_email = attrs.get('username')
        password = attrs.get('password')

        user = None
        if '@' in username_or_email:
            try:
                user = User.objects.get(email=username_or_email)
                attrs['username'] = user.username
            except User.DoesNotExist:
                pass

        data = super().validate(attrs)
        
        # Add user info to response safely
        if self.user:
            data['user_id'] = self.user.id
            data['username'] = self.user.username
            data['role'] = getattr(self.user, 'role', 'MEMBER')
        
        return data
