import logging
from typing import Dict, Any, Optional
from fastapi import HTTPException, status
from app.services.payments.base_payment_adapter import BasePaymentAdapter
from app.services.stripe_service import StripeService
from app.core.config import settings

logger = logging.getLogger(__name__)


class StripePaymentAdapter(BasePaymentAdapter):
    """
    Adaptateur officiel Stripe implémentant BasePaymentAdapter pour SD CHAT AI.
    Prend en charge les abonnements et paiements par carte bancaire internationale.
    """

    @property
    def provider_id(self) -> str:
        return "stripe"

    @property
    def display_name(self) -> str:
        return "Carte Bancaire / Stripe"

    @property
    def supported_currencies(self) -> list:
        return ["EUR", "USD", "GNF"]

    async def create_payment_session(
        self,
        user_id: str,
        plan_id: str,
        amount_cents_or_units: int,
        currency: str,
        success_url: str,
        cancel_url: str,
        user_email: Optional[str] = None,
        phone_number: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Délègue la création de session à StripeService avec vérification des clés."""
        if not settings.stripe_secret_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Le service de paiement Stripe n'est pas configuré sur ce serveur."
            )

        res = StripeService.create_checkout_session(
            user_id=user_id,
            email=user_email,
            success_url=success_url,
            cancel_url=cancel_url,
        )
        return {
            "provider": self.provider_id,
            "session_id": res["session_id"],
            "checkout_url": res["checkout_url"],
            "plan_id": plan_id,
        }

    def verify_webhook_signature(self, payload: bytes, signature: Optional[str]) -> Dict[str, Any]:
        """Vérifie la signature du webhook Stripe officiel."""
        return StripeService.handle_webhook(payload, signature or "")

    def get_merchant_requirements(self) -> Dict[str, Any]:
        return {
            "provider": "stripe",
            "type": "card",
            "kyc_verified": bool(settings.stripe_secret_key),
            "status": "active" if settings.stripe_secret_key else "inactive",
            "supported_currencies": self.supported_currencies,
            "note": "Paiement international sécurisé Stripe."
        }
