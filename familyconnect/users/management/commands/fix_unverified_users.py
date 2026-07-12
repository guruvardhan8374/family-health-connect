"""
Management command to fix existing users with is_otp_verified=False.
Run with: python manage.py fix_unverified_users
"""
from django.core.management.base import BaseCommand
from users.models import CustomUser


class Command(BaseCommand):
    help = 'Mark all existing users as OTP-verified so they can log in'

    def handle(self, *args, **options):
        updated = CustomUser.objects.filter(is_otp_verified=False).update(is_otp_verified=True)
        self.stdout.write(self.style.SUCCESS(f'Successfully marked {updated} users as OTP-verified.'))
