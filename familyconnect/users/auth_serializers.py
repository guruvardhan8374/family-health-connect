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

        # ── OPTIMIZED: Single DB query using .only() to fetch just needed fields ─
        lookup_field = 'email__iexact' if '@' in username_or_email else 'username__iexact'
        try:
            user = User.objects.only(
                'id', 'username', 'email', 'password',
                'is_active', 'role', 'is_otp_verified',
            ).get(**{lookup_field: username_or_email})
        except User.DoesNotExist:
            field = 'email address' if '@' in username_or_email else 'username'
            raise serializers.ValidationError(
                f'No account found with this {field}. Please register first.'
            )
        except User.MultipleObjectsReturned:
            user = User.objects.filter(
                **{lookup_field: username_or_email}
            ).only(
                'id', 'username', 'email', 'password',
                'is_active', 'role', 'is_otp_verified',
            ).order_by('-date_joined').first()

        # ── Active check on already-fetched object — zero extra DB hit ──────────
        if not user.is_active:
            raise serializers.ValidationError(
                'This account has been deactivated. Please contact support.'
            )

        # ── Password check directly — no extra authenticate() DB query ──────────
        if not user.check_password(password):
            raise serializers.ValidationError('Invalid password.')

        # ── Email Verification Check ──────────
        if hasattr(user, 'is_otp_verified') and not user.is_otp_verified:
            raise serializers.ValidationError({
                'detail': 'Please verify your email before logging in.',
                'email_unverified': True,
                'email': user.email
            })

        # ── Set self.user directly so parent generate tokens without another lookup
        attrs['username'] = user.username
        self.user = user

        # ── Generate tokens (reads self.user — no extra DB query) ────────────────
        data = super().validate(attrs)

        # ── Embed full profile so mobile needs ZERO extra API calls after login ──
        data['user_id']  = user.id
        data['username'] = user.username
        data['email']    = user.email
        data['role']     = getattr(user, 'role', 'MEMBER')

        # Include profile picture / phone from settings (single lightweight query)
        try:
            from settings_app.models import UserProfileSettings
            profile = UserProfileSettings.objects.only(
                'profile_picture', 'phone_number', 'bio'
            ).filter(user=user).first()
            data['profile_picture'] = profile.profile_picture if profile else ''
            data['phone_number']    = profile.phone_number    if profile else ''
            data['bio']             = profile.bio              if profile else ''
        except Exception:
            data['profile_picture'] = ''
            data['phone_number']    = ''
            data['bio']             = ''

        return data
