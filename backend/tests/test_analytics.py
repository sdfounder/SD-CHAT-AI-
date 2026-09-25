import uuid
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.database.connection import db_manager
from app.repositories.chat_repository import ChatRepository
from app.core.security import create_admin_access_token, AuthenticatedUser
from app.schemas.chat_schemas import SendMessageRequest
from app.services.chat_service import ChatService

client = TestClient(app)


def test_admin_analytics_endpoint_unauthenticated_and_forbidden():
    """
    Vérifie le contrôle d'accès strict sur l'endpoint analytics :
    - Non authentifié -> HTTP 401
    - Utilisateur standard (non admin) -> HTTP 403
    """
    # 1. Non authentifié
    resp_unauth = client.get("/api/v1/admin/analytics")
    assert resp_unauth.status_code == 401

    # 2. Utilisateur standard
    test_user_uid = f"standard-user-analytics-{uuid.uuid4().hex[:8]}"
    ChatRepository.ensure_user_profile(test_user_uid, email=f"{test_user_uid}@sd-chat.ai")
    user_headers = {"Authorization": f"Bearer dev-token-{test_user_uid}"}

    resp_forbidden = client.get("/api/v1/admin/analytics", headers=user_headers)
    assert resp_forbidden.status_code == 403
    assert "administrateur" in resp_forbidden.json()["detail"].lower()


def test_admin_analytics_endpoint_success_default_params():
    """
    Vérifie que l'administrateur peut récupérer l'ensemble des métriques d'inférence IA,
    volumétries, quotas et performances réelles avec succès (HTTP 200).
    """
    admin_token = create_admin_access_token("6e887b6b-3339-4297-89e0-d3ec2658a83a", "sekoudiaby433@gmail.com")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    resp = client.get("/api/v1/admin/analytics", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()

    # 1. Validation de la structure principale
    assert data["period"] == "7d"
    assert data["tier_filter"] == "all"
    assert data["provider_filter"] == "all"
    assert "summary" in data
    assert "time_series" in data
    assert "tier_breakdown" in data
    assert "quota_analytics" in data
    assert "performance" in data
    assert "errors_analytics" in data
    assert "conversations_attachments" in data
    assert "providers" in data

    # 2. Validation du résumé IA (Summary)
    summary = data["summary"]
    assert summary["total_requests"] >= 1
    assert summary["success_requests"] >= 1
    assert summary["success_rate_pct"] > 0
    assert summary["total_tokens"] > 0
    assert summary["total_messages"] >= 1
    assert summary["avg_latency_ms"] > 0
    assert summary["avg_ttft_ms"] > 0
    assert summary["estimated_cost_usd"] > 0
    assert summary["estimated_cost_eur"] > 0

    # 3. Validation de la répartition Free vs Premium
    assert "free" in data["tier_breakdown"]
    assert "premium" in data["tier_breakdown"]
    free_stats = data["tier_breakdown"]["free"]
    assert free_stats["users_count"] >= 1
    assert free_stats["quota_limit_per_user"] == 20

    # 4. Validation des providers multi-modèles (Gemini actif + SD LLM Core souverain)
    providers = data["providers"]
    assert len(providers) >= 2
    gemini_prov = next(p for p in providers if p["provider"] == "gemini")
    sd_core_prov = next(p for p in providers if p["provider"] == "sd_core")

    assert gemini_prov["is_active"] is True
    assert gemini_prov["requests_count"] >= 1
    assert sd_core_prov["is_active"] is False


def test_admin_analytics_period_and_filters():
    """Vérifie la robustesse des filtres de période, formule et fournisseur."""
    admin_token = create_admin_access_token("6e887b6b-3339-4297-89e0-d3ec2658a83a", "sekoudiaby433@gmail.com")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # 1. Période 24h
    resp_24h = client.get("/api/v1/admin/analytics?period=24h", headers=admin_headers)
    assert resp_24h.status_code == 200
    assert resp_24h.json()["period"] == "24h"

    # 2. Filtre Free
    resp_free = client.get("/api/v1/admin/analytics?tier=free", headers=admin_headers)
    assert resp_free.status_code == 200
    assert resp_free.json()["tier_filter"] == "free"

    # 3. Filtre Provider Gemini
    resp_gemini = client.get("/api/v1/admin/analytics?provider=gemini", headers=admin_headers)
    assert resp_gemini.status_code == 200
    assert resp_gemini.json()["provider_filter"] == "gemini"


def test_admin_analytics_privacy_and_email_masking():
    """Vérifie le respect strict de la confidentialité : les adresses emails des utilisateurs sont masquées."""
    admin_token = create_admin_access_token("6e887b6b-3339-4297-89e0-d3ec2658a83a", "sekoudiaby433@gmail.com")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    resp = client.get("/api/v1/admin/analytics", headers=admin_headers)
    assert resp.status_code == 200
    top_consumers = resp.json()["quota_analytics"]["top_quota_consumers"]

    for u in top_consumers:
        # L'email doit être masqué (ex: ad***@sd.media)
        assert "***" in u["masked_email"]
        assert "@" in u["masked_email"]
        assert "user_id" in u


def test_chat_service_real_telemetry_recording():
    """
    Vérifie qu'un échange avec le service de chat enregistre bien la télémétrie complète
    dans la table ai_request_metrics (latence, TTFT, tokens, coût estimé).
    """
    import asyncio

    async def _test():
        test_uid = f"telemetry-user-{uuid.uuid4().hex[:8]}"
        ChatRepository.ensure_user_profile(test_uid, email=f"{test_uid}@sd-chat.ai", tier="free")
        user = AuthenticatedUser(id=test_uid, email=f"{test_uid}@sd-chat.ai", tier="free")

        req = SendMessageRequest(
            content="Bonjour SD CHAT AI, teste la télémétrie d'inférence en Mission 10.",
            model="gemini-3.6-flash"
        )

        try:
            events = []
            async for chunk in ChatService.stream_chat(user, req):
                events.append(chunk)

            assert len(events) >= 2
            # Vérifier qu'une ligne a été créée dans ai_request_metrics
            with db_manager.connect() as conn:
                rows = conn.run(
                    """
                    SELECT provider, model, user_tier, total_tokens, latency_ms, ttft_ms, status, estimated_cost_usd
                    FROM public.ai_request_metrics
                    WHERE user_id = :uid
                    ORDER BY created_at DESC
                    LIMIT 1
                    """,
                    uid=test_uid
                )
                assert len(rows) == 1
                row = rows[0]
                assert row[0] == "gemini"
                assert row[1] in ("gemini-3.6-flash", "gemini-2.5-flash")
                assert row[2] == "free"
                assert row[3] > 0
                assert row[4] > 0
                assert row[5] > 0
                assert row[6] in ("success", "streaming_interrupted", "error")

        finally:
            with db_manager.connect() as conn:
                conn.run("DELETE FROM public.ai_request_metrics WHERE user_id = :uid", uid=test_uid)
                conn.run("DELETE FROM public.chat_messages WHERE user_id = :uid", uid=test_uid)
                conn.run("DELETE FROM public.chat_conversations WHERE user_id = :uid", uid=test_uid)
                conn.run("DELETE FROM public.profiles WHERE id = :uid", uid=test_uid)

    asyncio.run(_test())

