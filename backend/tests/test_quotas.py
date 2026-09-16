import uuid
from datetime import datetime, timezone, timedelta
import pytest
from fastapi.testclient import TestClient
from fastapi import HTTPException

from app.main import app
from app.database.connection import db_manager
from app.repositories.chat_repository import ChatRepository
from app.services.quota_service import (
    QuotaService,
    FREE_DAILY_MESSAGES_LIMIT,
    FREE_DAILY_ATTACHMENTS_LIMIT,
    PREMIUM_DAILY_MESSAGES_LIMIT,
    PREMIUM_DAILY_ATTACHMENTS_LIMIT,
)

client = TestClient(app)


def test_quota_endpoint_unauthenticated():
    """Vérifie que l'endpoint /api/v1/quota exige une authentification stricte."""
    response = client.get("/api/v1/quota")
    assert response.status_code == 401


def test_quota_endpoint_free_user():
    """Vérifie que le plan Free par défaut est correctement attribué et initialisé."""
    test_uid = f"free-user-{uuid.uuid4().hex[:8]}"
    headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    response = client.get("/api/v1/quota", headers=headers)
    assert response.status_code == 200
    data = response.json()

    assert data["user_id"] == test_uid
    assert data["plan"] == "free"
    assert data["is_premium"] is False
    assert data["messages_limit"] == FREE_DAILY_MESSAGES_LIMIT
    assert data["attachments_limit"] == FREE_DAILY_ATTACHMENTS_LIMIT
    assert data["messages_used"] == 0
    assert data["messages_remaining"] == FREE_DAILY_MESSAGES_LIMIT
    assert data["attachments_used"] == 0
    assert data["attachments_remaining"] == FREE_DAILY_ATTACHMENTS_LIMIT
    assert data["is_quota_exceeded"] is False
    assert "reset_at" in data


def test_quota_consume_and_exceed_messages():
    """
    Vérifie le décompte réel des messages et le blocage strict à 429
    lorsque le quota Free est épuisé.
    """
    test_uid = f"free-quota-test-{uuid.uuid4().hex[:8]}"

    # Initialisation
    status = QuotaService.get_quota_status(test_uid)
    assert status.messages_used == 0

    # Simuler l'atteinte du quota (ex: 20 messages)
    with db_manager.connect() as conn:
        conn.run(
            """
            UPDATE public.chat_user_usage
            SET messages_sent = :sent
            WHERE user_id = :uid AND period_start = CURRENT_DATE
            """,
            uid=test_uid,
            sent=FREE_DAILY_MESSAGES_LIMIT
        )

    # La prochaine tentative de consommation doit échouer en HTTP 429
    with pytest.raises(HTTPException) as exc_info:
        QuotaService.check_and_consume_message_quota(test_uid)

    assert exc_info.value.status_code == 429
    detail = exc_info.value.detail
    assert detail["error_code"] == "QUOTA_EXCEEDED"
    assert detail["plan"] == "free"
    assert detail["messages_limit"] == FREE_DAILY_MESSAGES_LIMIT


def test_chat_stream_blocked_when_quota_exceeded():
    """
    Vérifie que l'API POST /api/v1/chat/stream bloque immédiatement avec HTTP 429
    avant toute génération IA si le quota est dépassé.
    """
    test_uid = f"free-stream-test-{uuid.uuid4().hex[:8]}"
    headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    # Bloquer le quota pour cet utilisateur
    QuotaService.get_quota_status(test_uid)
    with db_manager.connect() as conn:
        conn.run(
            """
            UPDATE public.chat_user_usage
            SET messages_sent = :sent
            WHERE user_id = :uid AND period_start = CURRENT_DATE
            """,
            uid=test_uid,
            sent=FREE_DAILY_MESSAGES_LIMIT
        )

    response = client.post(
        "/api/v1/chat/stream",
        headers=headers,
        json={"content": "Bonjour SD CHAT AI", "conversation_id": None}
    )

    assert response.status_code == 429
    data = response.json()
    assert data["detail"]["error_code"] == "QUOTA_EXCEEDED"


def test_attachment_quota_free_user():
    """
    Vérifie la limite de pièces jointes pour un utilisateur Free (max 3/jour).
    Au-delà, l'upload est rejeté avec HTTP 429.
    """
    test_uid = f"free-attach-test-{uuid.uuid4().hex[:8]}"
    headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    # Initialiser la table
    QuotaService.get_quota_status(test_uid)

    # Téléverser 3 fichiers autorisés
    for i in range(FREE_DAILY_ATTACHMENTS_LIMIT):
        resp = client.post(
            "/api/v1/attachments/upload",
            headers=headers,
            files={"file": (f"test_{i}.txt", f"Contenu test {i}".encode("utf-8"), "text/plain")}
        )
        assert resp.status_code == 201, f"Échec upload {i}: {resp.text}"

    # 4e tentative -> doit être bloquée avec 429
    resp_blocked = client.post(
        "/api/v1/attachments/upload",
        headers=headers,
        files={"file": ("test_extra.txt", b"Fichier bloque", "text/plain")}
    )
    assert resp_blocked.status_code == 429
    data = resp_blocked.json()
    assert data["detail"]["error_code"] == "ATTACHMENTS_QUOTA_EXCEEDED"


def test_real_premium_subscription_entitlement():
    """
    Vérifie qu'un utilisateur avec un abonnement actif dans public.subscriptions
    reçoit les quotas Premium (500 messages, 50 pièces jointes) de façon vérifiable.
    """
    test_uid = f"sub-premium-{uuid.uuid4().hex[:8]}"
    headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    # Créer le profil via ChatRepository et insérer une souscription Stripe active dans Supabase
    ChatRepository.ensure_user_profile(test_uid)
    with db_manager.connect() as conn:
        conn.run(
            """
            INSERT INTO public.subscriptions (
                id, user_id, plan_id, status, current_period_end, created_at, updated_at
            )
            VALUES (
                :sub_id, :uid, 'premium', 'active', NOW() + INTERVAL '30 days', NOW(), NOW()
            )
            """,
            sub_id=str(uuid.uuid4()),
            uid=test_uid
        )

    # Vérification des quotas Premium via l'API
    response = client.get("/api/v1/quota", headers=headers)
    assert response.status_code == 200
    data = response.json()

    assert data["plan"] == "premium"
    assert data["is_premium"] is True
    assert data["messages_limit"] == PREMIUM_DAILY_MESSAGES_LIMIT
    assert data["attachments_limit"] == PREMIUM_DAILY_ATTACHMENTS_LIMIT

    # Nettoyage
    with db_manager.connect() as conn:
        conn.run("DELETE FROM public.subscriptions WHERE user_id = :uid", uid=test_uid)
        conn.run("DELETE FROM public.chat_user_usage WHERE user_id = :uid", uid=test_uid)
        conn.run("DELETE FROM public.profiles WHERE id = :uid", uid=test_uid)
