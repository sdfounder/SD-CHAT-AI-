import logging
from typing import Optional
from fastapi import APIRouter, Depends, Header, Request, status

from app.core.security import get_current_user, AuthenticatedUser
from app.schemas.billing_schemas import (
    CreateCheckoutRequest,
    CheckoutResponse,
    CreatePortalRequest,
    PortalResponse,
    SubscriptionDetailsResponse,
)
from app.services.stripe_service import StripeService
from app.services.payments import list_available_payment_methods

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/billing", tags=["Billing & Stripe"])


@router.get(
    "/payment-methods",
    summary="Lister les méthodes de paiement supportées",
    description="Retourne les passerelles de paiement disponibles (Stripe, Orange Money Guinée, MTN MoMo Guinée)."
)
async def get_payment_methods():
    return {"methods": list_available_payment_methods()}



@router.post(
    "/checkout",
    response_model=CheckoutResponse,
    summary="Créer une session de paiement Stripe Checkout",
    description="Génère l'URL Stripe Checkout officielle pour s'abonner au plan SD CHAT AI Premium."
)
async def create_checkout(
    request: CreateCheckoutRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    session_data = StripeService.create_checkout_session(
        user_id=current_user.id,
        email=current_user.email,
        name=current_user.full_name,
        price_id=request.price_id,
        success_url=request.success_url,
        cancel_url=request.cancel_url,
    )
    return CheckoutResponse(**session_data)


@router.post(
    "/portal",
    response_model=PortalResponse,
    summary="Créer une session Stripe Customer Portal",
    description="Génère l'URL sécurisée vers le portail client Stripe pour modifier les moyens de paiement ou gérer l'abonnement."
)
async def create_portal(
    request: CreatePortalRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    portal_url = StripeService.create_portal_session(
        user_id=current_user.id,
        return_url=request.return_url,
    )
    return PortalResponse(portal_url=portal_url)


@router.get(
    "/subscription",
    response_model=SubscriptionDetailsResponse,
    summary="Consulter l'état de l'abonnement Stripe de l'utilisateur",
    description="Retourne les détails consolidés de l'abonnement (statut, dates de renouvellement, identifiants Stripe)."
)
async def get_subscription(
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    sub_data = StripeService.get_user_subscription(current_user.id)
    return SubscriptionDetailsResponse(**sub_data)


@router.post(
    "/webhook",
    status_code=status.HTTP_200_OK,
    summary="Réception des webhooks officiels Stripe",
    description="Endpoint public appelé par Stripe avec vérification de la signature cryptographique."
)
async def stripe_webhook(
    request: Request,
    stripe_signature: Optional[str] = Header(None, alias="stripe-signature"),
):
    payload = await request.body()
    return StripeService.handle_webhook_event(payload, stripe_signature)
