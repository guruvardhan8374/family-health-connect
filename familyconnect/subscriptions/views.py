import stripe
from django.conf import settings
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from .models import Subscription, SubscriptionPlan
from decouple import config

stripe.api_key = config('STRIPE_SECRET_KEY', default='')

class StripeCheckoutView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        plan_id = request.data.get('plan_id')
        try:
            plan = SubscriptionPlan.objects.get(id=plan_id)
            
            # Create Stripe Checkout Session
            # In a real app, you'd use real Stripe price IDs
            checkout_session = stripe.checkout.Session.create(
                payment_method_types=['card'],
                line_items=[{
                    'price_data': {
                        'currency': 'usd',
                        'product_data': {'name': plan.name},
                        'unit_amount': int(plan.price * 100),
                    },
                    'quantity': 1,
                }],
                mode='subscription',
                success_url=settings.FRONTEND_URL + '/billing/success',
                cancel_url=settings.FRONTEND_URL + '/billing/cancel',
                customer_email=request.user.email,
            )
            return Response({'checkout_url': checkout_session.url})
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

class SubscriptionStatusView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            sub = request.user.subscription
            return Response({
                "plan": sub.plan.name,
                "status": sub.status,
                "end_date": sub.end_date,
                "max_members": sub.plan.max_members,
                "features": {
                    "ai": sub.plan.has_ai_analytics,
                    "voice": sub.plan.has_voice_assistant
                }
            })
        except Subscription.DoesNotExist:
            return Response({"status": "NO_SUBSCRIPTION"}, status=status.HTTP_404_NOT_FOUND)
