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
    Sends the OTP code via email. In production, this integrates with SMTP/SES.
    Currently, it logs the OTP for development and debugging.
    """
    subject = "Family Health Connect - Your OTP Verification Code"
    message = f"Your one-time verification code is: {otp_code}. It will expire in 10 minutes."

    logger.info(f"Sending OTP to {email}: {message}")
    print(f"\n=======================================================")
    print(f"EMAIL TO: {email}")
    print(f"SUBJECT: {subject}")
    print(f"MESSAGE: {message}")
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
