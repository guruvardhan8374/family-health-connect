from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()


class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        username_or_email = attrs.get('username', '').strip()
        password = attrs.get('password', '')

        if not username_or_email:
            raise serializers.ValidationError({'username': 'This field is required.'})
        if not password:
            raise serializers.ValidationError({'password': 'This field is required.'})

        # Resolve email → username (case-insensitive)
        if '@' in username_or_email:
            try:
                user = User.objects.get(email__iexact=username_or_email)
                attrs['username'] = user.username
            except User.DoesNotExist:
                raise serializers.ValidationError(
                    'No account found with this email address. Please register first.'
                )
            except User.MultipleObjectsReturned:
                # Edge case: duplicate emails — take the most recent
                user = User.objects.filter(email__iexact=username_or_email).order_by('-date_joined').first()
                attrs['username'] = user.username
        else:
            # Username login — case-insensitive lookup
            try:
                user = User.objects.get(username__iexact=username_or_email)
                attrs['username'] = user.username  # normalise to stored case
            except User.DoesNotExist:
                raise serializers.ValidationError(
                    'No account found with this username. Please check or register.'
                )

        # Check account is active before handing off to parent
        resolved_user = User.objects.filter(username=attrs['username']).first()
        if resolved_user and not resolved_user.is_active:
            raise serializers.ValidationError(
                'This account has been deactivated. Please contact support.'
            )

        # Parent handles password check and token generation
        data = super().validate(attrs)

        # Attach user info to token response
        if self.user:
            data['user_id']  = self.user.id
            data['username'] = self.user.username
            data['email']    = self.user.email
            data['role']     = getattr(self.user, 'role', 'MEMBER')

        return data
