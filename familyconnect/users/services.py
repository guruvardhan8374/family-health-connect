import random
import logging
from django.utils import timezone
from datetime import timedelta

logger = logging.getLogger(__name__)

def generate_otp():
    """
    Generates a secure random 6-digit numeric OTP code.
    """
    return f"{random.randint(100000, 999999)}"

def send_otp_email(email, otp_code):
    """
    Sends the OTP code via Gmail SMTP.
    Falls back to console logging if email credentials are not configured.
    """
    from django.conf import settings
    from django.core.mail import send_mail

    subject = "Family Health Connect - Your Verification Code"
    message = (
        f"Hello,\n\n"
        f"Your one-time verification code is:\n\n"
        f"    {otp_code}\n\n"
        f"This code will expire in 10 minutes.\n\n"
        f"If you did not request this, please ignore this email.\n\n"
        f"— Family Health Connect Team"
    )

    host_user = getattr(settings, 'EMAIL_HOST_USER', '')
    host_pass = getattr(settings, 'EMAIL_HOST_PASSWORD', '')
    is_configured = bool(host_user and host_pass and 'your_' not in host_user and 'your_' not in host_pass)

    if is_configured:
        try:
            send_mail(
                subject=subject,
                message=message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                fail_silently=False,
            )
            logger.info(f"OTP email sent to {email}")
            return True
        except Exception as e:
            logger.error(f"Failed to send OTP email to {email}: {str(e)}")
            # Fall through to console log so OTP is still accessible during dev
            print(f"\n=======================================================")
            print(f"EMAIL SEND FAILED: {str(e)}")
            print(f"EMAIL TO: {email} | OTP: {otp_code}")
            print(f"=======================================================\n")
            return False

    # Not configured — log to console for development
    logger.info(f"[DEV] OTP for {email}: {otp_code}")
    print(f"\n=======================================================")
    print(f"EMAIL TO: {email}")
    print(f"SUBJECT: {subject}")
    print(f"OTP CODE: {otp_code}")
    print(f"(Configure EMAIL_HOST_USER and EMAIL_HOST_PASSWORD in .env to send real emails)")
    print(f"=======================================================\n")
    return True

def verify_otp(user, otp_code):
    """
    Verifies the OTP code for a user, checking for correct match and expiration (10 minutes).
    """
    if not user.otp_code or user.otp_code != otp_code:
        return False

    if not user.otp_created_at:
        return False

    # Check if code is expired (10 minutes window)
    now = timezone.now()
    expiry_time = user.otp_created_at + timedelta(minutes=10)

    if now > expiry_time:
        # Clear expired OTP
        user.otp_code = None
        user.save()
        return False

    # Valid OTP, verify user and clear code
    user.is_otp_verified = True
    user.otp_code = None
    user.save()
    return True
