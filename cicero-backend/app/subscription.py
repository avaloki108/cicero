import stripe
from fastapi import HTTPException, Depends
from sqlalchemy.orm import Session
from app.database import get_db, User, SubscriptionTier
from app.auth import get_current_user
from app.config import settings
from datetime import datetime

stripe.api_key = settings.STRIPE_SECRET_KEY


def create_checkout_session(user: User, db: Session) -> dict:
    """Create Stripe Checkout session for Premium subscription"""
    try:
        # Create or get Stripe customer
        if not user.stripe_customer_id:
            customer = stripe.Customer.create(
                email=user.email,
                metadata={"firebase_uid": user.firebase_uid}
            )
            user.stripe_customer_id = customer.id
            db.commit()
        else:
            customer = stripe.Customer.retrieve(user.stripe_customer_id)

        # Create checkout session
        checkout_session = stripe.checkout.Session.create(
            customer=customer.id,
            payment_method_types=["card"],
            line_items=[{
                "price": settings.STRIPE_PREMIUM_PRICE_ID,
                "quantity": 1,
            }],
            mode="subscription",
            success_url=f"{settings.ALLOWED_ORIGINS.split(',')[0]}/subscription/success?session_id={{CHECKOUT_SESSION_ID}}",
            cancel_url=f"{settings.ALLOWED_ORIGINS.split(',')[0]}/subscription/cancel",
            metadata={
                "user_id": str(user.id),
                "firebase_uid": user.firebase_uid
            }
        )

        return {"checkout_url": checkout_session.url, "session_id": checkout_session.id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating checkout session: {str(e)}")


def handle_stripe_webhook(payload: bytes, sig_header: str) -> dict:
    """Handle Stripe webhook events"""
    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, settings.STRIPE_WEBHOOK_SECRET
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid payload")
    except stripe.error.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Invalid signature")

    # Handle the event
    event_type = event["type"]
    event_data = event["data"]["object"]

    from app.database import SessionLocal
    db = SessionLocal()

    try:
        if event_type == "checkout.session.completed":
            # Subscription created
            session = event_data
            user_id = int(session["metadata"]["user_id"])
            user = db.query(User).filter(User.id == user_id).first()
            
            if user:
                subscription_id = session.get("subscription")
                user.stripe_subscription_id = subscription_id
                user.subscription_tier = SubscriptionTier.PREMIUM
                db.commit()

        elif event_type == "customer.subscription.updated":
            # Subscription updated (e.g., renewed, changed)
            subscription = event_data
            user = db.query(User).filter(
                User.stripe_subscription_id == subscription["id"]
            ).first()
            
            if user:
                if subscription["status"] in ["active", "trialing"]:
                    user.subscription_tier = SubscriptionTier.PREMIUM
                elif subscription["status"] in ["canceled", "unpaid", "past_due"]:
                    user.subscription_tier = SubscriptionTier.FREE
                    user.stripe_subscription_id = None
                db.commit()

        elif event_type == "customer.subscription.deleted":
            # Subscription canceled
            subscription = event_data
            user = db.query(User).filter(
                User.stripe_subscription_id == subscription["id"]
            ).first()
            
            if user:
                user.subscription_tier = SubscriptionTier.FREE
                user.stripe_subscription_id = None
                db.commit()

        return {"status": "success"}
    finally:
        db.close()


def cancel_subscription(user: User, db: Session) -> dict:
    """Cancel user's subscription"""
    if not user.stripe_subscription_id:
        raise HTTPException(status_code=400, detail="No active subscription to cancel")

    try:
        subscription = stripe.Subscription.retrieve(user.stripe_subscription_id)
        subscription.cancel_at_period_end = True
        subscription.save()

        return {"message": "Subscription will be canceled at the end of the billing period"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error canceling subscription: {str(e)}")


def get_subscription_status(user: User) -> dict:
    """Get user's subscription status"""
    queries_limit = 5 if user.subscription_tier == SubscriptionTier.FREE else None
    
    return {
        "tier": user.subscription_tier.value,
        "queries_today": user.queries_today,
        "queries_limit": queries_limit,
        "stripe_customer_id": user.stripe_customer_id,
        "stripe_subscription_id": user.stripe_subscription_id
    }

