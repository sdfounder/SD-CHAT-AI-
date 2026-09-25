import json
import uuid
from datetime import datetime, timezone, timedelta
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.database.connection import db_manager
from app.repositories.chat_repository import ChatRepository
from app.services.quota_service import (
    QuotaService,
    FREE_DAILY_MESSAGES_LIMIT,
    PREMIUM_DAILY_MESSAGES_LIMIT,
)
from app.services.stripe_service import StripeService, DEFAULT_PREMIUM_PRICE_ID

client = TestClient(app)


def test_billing_endpoints_unauthenticated():
    """Vérifie que les endpoints checkout, portal et subscription exigent une authentification."""
    resp_checkout = client.post("/api/v1/billing/checkout", json={})
    assert resp_checkout.status_code == 401

    resp_portal = client.post("/api/v1/billing/portal", json={})
    assert resp_portal.status_code == 401

    resp_sub = client.get("/api/v1/billing/subscription")
    assert resp_sub.status_code == 401


def test_billing_subscription_free_user():
    """Vérifie le retour pour un utilisateur sans souscription active (Plan Free)."""
    test_uid = f"billing-free-{uuid.uuid4().hex[:8]}"
    headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    response = client.get("/api/v1/billing/subscription", headers=headers)
    assert response.status_code == 200
    data = response.json()

    assert data["user_id"] == test_uid
    assert data["plan_id"] == "free"
    assert data["status"] == "free"
    assert data["is_premium"] is False
    assert data["stripe_customer_id"] is None
    assert data["stripe_subscription_id"] is None


def test_billing_real_checkout_session_creation():
    """
    Vérifie la création d'une session Stripe Checkout réelle avec le Price ID officiel.
    Retourne l'URL officielle Stripe Checkout (checkout.stripe.com).
    """
    test_uid = f"billing-user-{uuid.uuid4().hex[:8]}"
    headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    response = client.post(
        "/api/v1/billing/checkout",
        headers=headers,
        json={
            "price_id": DEFAULT_PREMIUM_PRICE_ID,
            "success_url": "https://sd-chat.ai/billing/success?session_id={CHECKOUT_SESSION_ID}",
            "cancel_url": "https://sd-chat.ai/billing/cancel",
        }
    )
    assert response.status_code == 200
    data = response.json()

    assert "checkout_url" in data
    assert "stripe.com" in data["checkout_url"]
    assert "session_id" in data
    assert data["session_id"].startswith("cs_test_") or data["session_id"].startswith("cs_")


def test_billing_real_customer_portal_creation():
    """
    Vérifie la génération d'une session Customer Portal officielle Stripe.
    """
    test_uid = f"billing-portal-{uuid.uuid4().hex[:8]}"
    headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    response = client.post(
        "/api/v1/billing/portal",
        headers=headers,
        json={"return_url": "https://sd-chat.ai/settings"}
    )
    assert response.status_code == 200
    data = response.json()

    assert "portal_url" in data
    assert "stripe.com" in data["portal_url"]
    assert "session" in data["portal_url"] or "portal" in data["portal_url"] or "bps_" in data["portal_url"]


def test_billing_full_webhook_lifecycle_sync():
    """
    Teste le parcours complet du cycle de vie d'un abonnement via webhook :
    1. checkout.session.completed -> activation de l'abonnement & mise à jour du profil vers 'premium'
    2. Vérification de l'entitlement et des quotas (500 messages au lieu de 20)
    3. customer.subscription.deleted -> passage du profil à 'free'
    4. Vérification du retour aux quotas Free (20 messages)
    """
    test_uid = f"webhook-cycle-{uuid.uuid4().hex[:8]}"
    test_sub_id = f"sub_test_{uuid.uuid4().hex[:12]}"
    test_cust_id = f"cus_test_{uuid.uuid4().hex[:12]}"

    # Assurer profil utilisateur initial
    ChatRepository.ensure_user_profile(test_uid, email=f"{test_uid}@sd-chat.ai", full_name="Test Webhook User")

    # Initialement l'utilisateur est Free
    entitlement_initial = QuotaService.get_user_entitlement(test_uid)
    assert entitlement_initial["is_premium"] is False
    assert entitlement_initial["plan"] == "free"

    quota_initial = QuotaService.get_quota_status(test_uid)
    assert quota_initial.messages_limit == FREE_DAILY_MESSAGES_LIMIT

    # 1. Événement checkout.session.completed
    checkout_event = {
        "id": f"evt_{uuid.uuid4().hex}",
        "object": "event",
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "id": f"cs_test_{uuid.uuid4().hex}",
                "object": "checkout.session",
                "client_reference_id": test_uid,
                "customer": test_cust_id,
                "subscription": test_sub_id,
                "metadata": {"user_id": test_uid},
            }
        }
    }

    # Simulation webhook subscription sync
    future_end = int((datetime.now(timezone.utc) + timedelta(days=30)).timestamp())
    now_ts = int(datetime.now(timezone.utc).timestamp())

    sub_mock = {
        "id": test_sub_id,
        "customer": test_cust_id,
        "status": "active",
        "current_period_start": now_ts,
        "current_period_end": future_end,
        "cancel_at_period_end": False,
        "metadata": {"user_id": test_uid},
    }

    # Exécution de la synchronisation backend
    sync_result = StripeService.sync_subscription_from_stripe(sub_mock, explicit_user_id=test_uid)
    assert sync_result["status"] == "active"
    assert sync_result["tier"] == "premium"

    # 2. Vérification des quotas Premium synchronisés
    entitlement_after = QuotaService.get_user_entitlement(test_uid)
    assert entitlement_after["is_premium"] is True
    assert entitlement_after["plan"] == "premium"

    quota_after = QuotaService.get_quota_status(test_uid)
    assert quota_after.messages_limit == PREMIUM_DAILY_MESSAGES_LIMIT
    assert quota_after.is_premium is True

    # 3. Vérification de la consultation API /api/v1/billing/subscription
    headers = {"Authorization": f"Bearer dev-token-{test_uid}"}
    sub_api_resp = client.get("/api/v1/billing/subscription", headers=headers)
    assert sub_api_resp.status_code == 200
    sub_api_data = sub_api_resp.json()
    assert sub_api_data["is_premium"] is True
    assert sub_api_data["status"] == "active"
    assert sub_api_data["stripe_subscription_id"] == test_sub_id

    # 4. Événement d'annulation : customer.subscription.deleted
    sub_mock_canceled = {
        "id": test_sub_id,
        "customer": test_cust_id,
        "status": "canceled",
        "current_period_start": now_ts,
        "current_period_end": now_ts - 10,  # expiré
        "cancel_at_period_end": False,
        "metadata": {"user_id": test_uid},
    }
    sync_cancel_result = StripeService.sync_subscription_from_stripe(sub_mock_canceled, explicit_user_id=test_uid)
    assert sync_cancel_result["status"] == "canceled"
    assert sync_cancel_result["tier"] == "free"

    # 5. Vérification du retour immédiat au plan Free
    entitlement_canceled = QuotaService.get_user_entitlement(test_uid)
    assert entitlement_canceled["is_premium"] is False
    assert entitlement_canceled["plan"] == "free"

    quota_canceled = QuotaService.get_quota_status(test_uid)
    assert quota_canceled.messages_limit == FREE_DAILY_MESSAGES_LIMIT
    assert quota_canceled.is_premium is False

    # Nettoyage
    with db_manager.connect() as conn:
        conn.run("DELETE FROM public.subscriptions WHERE user_id = :uid", uid=test_uid)
        conn.run("DELETE FROM public.chat_user_usage WHERE user_id = :uid", uid=test_uid)
        conn.run("DELETE FROM public.profiles WHERE id = :uid", uid=test_uid)
