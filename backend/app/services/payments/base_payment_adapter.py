from abc import ABC, abstractmethod
from typing import Dict, Any, Optional


class BasePaymentAdapter(ABC):
    """
    Interface abstraite normalisée pour tous les fournisseurs de paiement de SD CHAT AI :
    - Stripe (Cartes bancaires internationales, Apple Pay, Google Pay)
    - Mobile Money Guinée (Orange Money / MTN MoMo) via API marchande sécurisée.
    RÈGLE ABSOLUE :
    - Zéro simulation de faux paiement (pas de mock).
    - L'activation requiert des identifiants marchands réels validés côté serveur.
    """

    @property
    @abstractmethod
    def provider_id(self) -> str:
        """Identifiant unique du fournisseur (ex: 'stripe', 'orange_money_gn', 'mtn_momo_gn')."""
        pass

    @property
    @abstractmethod
    def display_name(self) -> str:
        """Nom lisible pour l'utilisateur (ex: 'Carte bancaire / Stripe', 'Orange Money Guinée')."""
        pass

    @property
    @abstractmethod
    def supported_currencies(self) -> list:
        """Devises acceptées (ex: ['EUR', 'USD'] pour Stripe, ['GNF'] pour Mobile Money)."""
        pass

    @abstractmethod
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
        """Crée une session de paiement officielle sécurisée."""
        pass

    @abstractmethod
    def verify_webhook_signature(self, payload: bytes, signature: Optional[str]) -> Dict[str, Any]:
        """Valide la signature cryptographique du webhook distant."""
        pass

    @abstractmethod
    def get_merchant_requirements(self) -> Dict[str, Any]:
        """Retourne les conditions marchandes, exigences KYC et frais réels applicables."""
        pass
