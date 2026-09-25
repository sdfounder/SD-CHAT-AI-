from typing import Dict
from app.services.payments.base_payment_adapter import BasePaymentAdapter
from app.services.payments.stripe_adapter import StripePaymentAdapter
from app.services.payments.mobile_money_adapter import MobileMoneyGuineaAdapter

_PAYMENT_ADAPTERS: Dict[str, BasePaymentAdapter] = {
    "stripe": StripePaymentAdapter(),
    "orange_money_gn": MobileMoneyGuineaAdapter("orange_money"),
    "mtn_momo_gn": MobileMoneyGuineaAdapter("mtn_momo"),
}


def get_payment_adapter(provider_id: str) -> BasePaymentAdapter:
    adapter = _PAYMENT_ADAPTERS.get(provider_id.lower())
    if not adapter:
        raise ValueError(f"Fournisseur de paiement non supporté : {provider_id}")
    return adapter


def list_available_payment_methods() -> list:
    return [
        adapter.get_merchant_requirements()
        for adapter in _PAYMENT_ADAPTERS.values()
    ]


__all__ = [
    "BasePaymentAdapter",
    "StripePaymentAdapter",
    "MobileMoneyGuineaAdapter",
    "get_payment_adapter",
    "list_available_payment_methods",
]
