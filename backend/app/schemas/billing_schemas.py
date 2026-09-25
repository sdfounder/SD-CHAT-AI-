from typing import Optional
from datetime import datetime
from pydantic import BaseModel, Field


class CreateCheckoutRequest(BaseModel):
    """Demande d'ouverture d'une session de paiement Stripe Checkout."""
    price_id: Optional[str] = Field(
        default=None,
        description="Identifiant Stripe du tarif récurrent (ex: price_1UGRP9JkgRUEINU8rsFR8zBZ)"
    )
    success_url: Optional[str] = Field(
        default=None,
        description="URL de redirection après paiement réussi"
    )
    cancel_url: Optional[str] = Field(
        default=None,
        description="URL de redirection en cas d'annulation"
    )


class CheckoutResponse(BaseModel):
    """Réponse contenant l'URL hébergée Stripe Checkout."""
    checkout_url: str
    session_id: str


class CreatePortalRequest(BaseModel):
    """Demande d'accès au portail de facturation autonome Stripe Customer Portal."""
    return_url: Optional[str] = Field(
        default=None,
        description="URL de retour dans l'application après consultation du portail"
    )


class PortalResponse(BaseModel):
    """Réponse contenant l'URL sécurisée du Stripe Customer Portal."""
    portal_url: str


class SubscriptionDetailsResponse(BaseModel):
    """Détails consolidés de l'abonnement et des droits Premium."""
    user_id: str
    plan_id: str
    status: str
    is_premium: bool
    stripe_customer_id: Optional[str] = None
    stripe_subscription_id: Optional[str] = None
    current_period_start: Optional[datetime] = None
    current_period_end: Optional[datetime] = None
    cancel_at_period_end: bool = False
