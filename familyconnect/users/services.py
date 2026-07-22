import random
import hashlib
import logging
from django.utils import timezone
from datetime import timedelta
from django.conf import settings
from django.core.mail import EmailMultiAlternatives

logger = logging.getLogger(__name__)

OTP_EXPIRY_MINUTES = 5
MAX_FAILED_ATTEMPTS = 5

def generate_otp():
    """
    Generates a cryptographically secure random 6-digit numeric OTP code.
    """
    return f"{random.SystemRandom().randint(100000, 999999)}"

def hash_otp(otp_code):
    """
    Hashes the OTP code with SHA-256 for secure DB storage.
    """
    secret = getattr(settings, 'SECRET_KEY', 'family_health_connect_secret')
    return hashlib.sha256(f"{otp_code}:{secret}".encode('utf-8')).hexdigest()

def send_otp_email(email, otp_code):
    """
    Sends a professional HTML OTP email via SMTP.
    Falls back to console output if SMTP credentials are missing or during local dev.
    """
    subject = "Family Health Connect - Email Verification Code"
    
    # Plain text alternative
    text_content = (
        f"Welcome to Family Health Connect!\n\n"
        f"Your verification code is: {otp_code}\n\n"
        f"This code will expire in {OTP_EXPIRY_MINUTES} minutes.\n"
        f"For your security, do not share this code with anyone.\n\n"
        f"— Family Health Connect Security Team"
    )
    
    # Professional HTML template
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Email Verification</title>
        <style>
            body {{
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                background-color: #0F172A;
                color: #F8FAFC;
                margin: 0;
                padding: 40px 20px;
            }}
            .container {{
                max-width: 520px;
                margin: 0 auto;
                background: #1E293B;
                border-radius: 24px;
                border: 1px solid rgba(255, 255, 255, 0.1);
                padding: 40px 32px;
                box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5);
            }}
            .header {{
                text-align: center;
                margin-bottom: 32px;
            }}
            .badge {{
                display: inline-block;
                background: #14B8A6;
                color: #FFFFFF;
                font-weight: 700;
                font-size: 14px;
                padding: 8px 16px;
                border-radius: 12px;
                text-transform: uppercase;
                letter-spacing: 1px;
            }}
            .title {{
                font-size: 24px;
                font-weight: 700;
                color: #FFFFFF;
                margin-top: 16px;
                margin-bottom: 8px;
            }}
            .subtitle {{
                font-size: 15px;
                color: #94A3B8;
                line-height: 1.5;
            }}
            .otp-box {{
                background: rgba(20, 184, 166, 0.1);
                border: 2px dashed #14B8A6;
                border-radius: 16px;
                padding: 24px;
                text-align: center;
                margin: 32px 0;
            }}
            .otp-code {{
                font-family: 'Courier New', Courier, monospace;
                font-size: 38px;
                font-weight: 800;
                letter-spacing: 10px;
                color: #2DD4BF;
            }}
            .expiry {{
                font-size: 13px;
                color: #94A3B8;
                margin-top: 10px;
            }}
            .warning-card {{
                background: rgba(239, 68, 68, 0.1);
                border: 1px solid rgba(239, 68, 68, 0.3);
                border-radius: 12px;
                padding: 16px;
                font-size: 13px;
                color: #FCA5A5;
                line-height: 1.5;
                margin-bottom: 28px;
            }}
            .footer {{
                text-align: center;
                font-size: 12px;
                color: #64748B;
                border-top: 1px solid rgba(255, 255, 255, 0.1);
                padding-top: 20px;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="badge">Family Health Connect</div>
                <div class="title">Verify Your Email Address</div>
                <div class="subtitle">Use the verification code below to complete your registration or login.</div>
            </div>
            
            <div class="otp-box">
                <div class="otp-code">{otp_code}</div>
                <div class="expiry">Expires in <strong>{OTP_EXPIRY_MINUTES} minutes</strong></div>
            </div>
            
            <div class="warning-card">
                <strong>🔒 Security Reminder:</strong> Never share this code with anyone. Family Health Connect staff will never ask for your verification code.
            </div>
            
            <div class="footer">
                &copy; 2026 Family Health Connect. All rights reserved.<br>
                If you did not request this code, please ignore this message.
            </div>
        </div>
    </body>
    </html>
    """

    host_user = getattr(settings, 'EMAIL_HOST_USER', '')
    host_pass = getattr(settings, 'EMAIL_HOST_PASSWORD', '')
    is_configured = bool(host_user and host_pass and 'your_' not in host_user and 'your_' not in host_pass)

    if is_configured:
        try:
            from django.core.mail import get_connection
            # 4-second connection timeout prevents network/ISP socket blocks from hanging API requests
            connection = get_connection(
                backend=settings.EMAIL_BACKEND,
                timeout=4,
            )
            msg = EmailMultiAlternatives(
                subject=subject,
                body=text_content,
                from_email=settings.DEFAULT_FROM_EMAIL or host_user,
                to=[email],
                connection=connection,
            )
            msg.attach_alternative(html_content, "text/html")
            msg.send(fail_silently=False)
            logger.info(f"OTP HTML email sent to {email}")
            return True
        except Exception as e:
            logger.error(f"Failed to send OTP email to {email}: {str(e)}")
            print(f"\n=======================================================")
            print(f"EMAIL SEND NOTICE (Network/SMTP Timeout): {str(e)}")
            print(f"EMAIL TO: {email} | OTP: {otp_code}")
            print(f"=======================================================\n")
            return True

    # Dev fallback logging
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
    Verifies the OTP code for a user, enforcing 5-minute expiry and max 5 failed attempts.
    Returns dict: {'status': 'success'|'expired'|'max_attempts'|'invalid', 'message': str}
    """
    if not user.otp_code or not user.otp_created_at:
        return {
            'status': 'invalid',
            'message': 'No verification code found. Please request a new code.'
        }

    # Check maximum failed attempts
    if getattr(user, 'otp_failed_attempts', 0) >= MAX_FAILED_ATTEMPTS:
        user.otp_code = None
        user.save(update_fields=['otp_code'])
        return {
            'status': 'max_attempts',
            'message': 'Maximum verification attempts exceeded. Please request a new code.'
        }

    # Check 5-minute expiry
    now = timezone.now()
    expiry_time = user.otp_created_at + timedelta(minutes=OTP_EXPIRY_MINUTES)
    if now > expiry_time:
        user.otp_code = None
        user.save(update_fields=['otp_code'])
        return {
            'status': 'expired',
            'message': 'OTP has expired. Please request a new code.'
        }

    # Compare hashed OTP or plain OTP (for fallback)
    target_hash = hash_otp(otp_code)
    is_valid = (user.otp_code == target_hash or user.otp_code == otp_code)

    if not is_valid:
        user.otp_failed_attempts = getattr(user, 'otp_failed_attempts', 0) + 1
        user.save(update_fields=['otp_failed_attempts'])
        remaining = MAX_FAILED_ATTEMPTS - user.otp_failed_attempts
        return {
            'status': 'invalid',
            'message': f'Invalid OTP code. {remaining} attempt(s) remaining.' if remaining > 0 else 'Invalid OTP. Attempts limit reached.'
        }

    # OTP match successful! Verify user and wipe OTP credentials
    user.is_otp_verified = True
    user.is_active = True
    user.otp_code = None
    user.otp_created_at = None
    user.otp_failed_attempts = 0
    user.save()
    
    return {
        'status': 'success',
        'message': 'Email verified successfully.'
    }
