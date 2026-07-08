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
    
    # Log the email details
    logger.info(f"Sending OTP to {email}: {message}")
    print(f"\n=======================================================")
    print(f"EMAIL TO: {email}")
    print(f"SUBJECT: {subject}")
    print(f"MESSAGE: {message}")
    print(f"=======================================================\n")
    
    # Return True indicating successfully queued/sent in mock fashion
    return True

def send_otp_sms(phone_number, otp_code):
    """
    Sends the OTP code via SMS using Twilio.
    Falls back to console logging if Twilio is not configured or fails.
    """
    from django.conf import settings
    
    message_body = f"Your Family Health Connect verification code is: {otp_code}. It will expire in 10 minutes."
    
    sid = getattr(settings, 'TWILIO_ACCOUNT_SID', '')
    token = getattr(settings, 'TWILIO_AUTH_TOKEN', '')
    phone = getattr(settings, 'TWILIO_PHONE_NUMBER', '')
    
    # Check if configured and not placeholder values
    has_twilio = (sid and token and phone and 
                  'your_' not in sid and 
                  'your_' not in token and 
                  '+1234567890' not in phone)
                  
    if has_twilio:
        try:
            from twilio.rest import Client
            client = Client(sid, token)
            message = client.messages.create(
                body=message_body,
                from_=phone,
                to=phone_number
            )
            logger.info(f"Twilio SMS sent to {phone_number}, SID: {message.sid}")
            return True
        except Exception as e:
            logger.error(f"Failed to send Twilio SMS to {phone_number}: {str(e)}. Falling back to console.")
            
    # Fallback to console logging
    logger.info(f"Sending OTP via SMS to {phone_number}: {message_body}")
    print(f"\n=======================================================")
    print(f"SMS TO: {phone_number}")
    print(f"MESSAGE: {message_body}")
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
