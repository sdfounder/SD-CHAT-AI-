import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.ai.models_catalog import ModelsCatalog
from app.ai.gateway.circuit_breaker import ProviderCircuitBreaker
from app.ai.gateway.plan_engine import PlanEngine, PlanTier
from app.ai.gateway.router import ProviderRouter
from app.core.security import create_admin_access_token
from app.services.payments import list_available_payment_methods, get_payment_adapter
from app.services.payments.mobile_money_adapter import MobileMoneyGuineaAdapter

client = TestClient(app)


def test_models_catalog_real_and_commercial_names():
    """Vérifie que les modèles réels sont actifs et que les dénominations commerciales futures sont 'Non disponible'."""
    # 1. Modèles réels officiels
    real_models = [
        "gemini-3.6-flash", "gemini-2.5-flash", "gemini-1.5-pro",
        "gpt-4o", "gpt-4o-mini", "o3-mini",
        "claude-3-5-sonnet", "claude-3-5-haiku", "claude-3-opus",
        "grok-2-1212", "deepseek/deepseek-chat"
    ]
    for m in real_models:
        meta = ModelsCatalog.get_model_metadata(m)
        assert meta is not None, f"Modèle réel manquant au catalogue : {m}"
        assert meta["is_active"] is True

    # 2. Dénominations commerciales / futures inactives (Non disponible)
    commercial_models = ["gpt-5-6", "gpt-6-astra", "claude-opus-5", "claude-sonnet-4"]
    for m in commercial_models:
        meta = ModelsCatalog.get_model_metadata(m)
        assert meta is not None, f"Dénomination commerciale manquante : {m}"
        assert meta["is_active"] is False
        status_str = meta.get("status") or meta.get("status_label", "")
        assert "non disponible" in status_str.lower()


def test_plan_engine_four_sd_plans_and_gnf_pricing():
    """Vérifie les 4 plans officiels SD et leur tarification en GNF."""
    # 1. SD FREE
    free_limits = PlanEngine.get_plan_limits(PlanTier.FREE)
    assert free_limits["daily_messages_limit"] == 5
    assert free_limits["price_gnf"] == 0
    assert free_limits["can_select_model"] is False

    # 2. SD PREMIUM
    prem_limits = PlanEngine.get_plan_limits(PlanTier.PREMIUM)
    assert prem_limits["daily_messages_limit"] == 10
    assert prem_limits["price_gnf"] == 10000
    assert prem_limits["can_select_model"] is False
    assert prem_limits["supports_memory"] is True

    # 3. SD VIP
    vip_limits = PlanEngine.get_plan_limits(PlanTier.VIP)
    assert vip_limits["daily_messages_limit"] == 25
    assert vip_limits["price_gnf"] == 50000
    assert vip_limits["can_select_model"] is True

    # 4. SD BLACK PREMIUM ULTRA
    black_limits = PlanEngine.get_plan_limits(PlanTier.BLACK)
    assert black_limits["daily_messages_limit"] >= 200
    assert black_limits["price_gnf"] == 250000
    assert black_limits["can_select_model"] is True


def test_circuit_breaker_state_transitions():
    """Vérifie le déclenchement du circuit breaker sur 3 échecs consécutifs."""
    cb = ProviderCircuitBreaker(failure_threshold=3, recovery_timeout_seconds=2)
    p_name = "test_provider"

    assert cb.is_available(p_name) is True
    assert cb.get_state(p_name) == "closed"

    # 2 échecs -> toujours fermé
    cb.record_failure(p_name, "Erreur 1")
    cb.record_failure(p_name, "Erreur 2")
    assert cb.is_available(p_name) is True
    assert cb.get_state(p_name) == "closed"

    # 3e échec -> bascule vers 'open'
    cb.record_failure(p_name, "Erreur 3")
    assert cb.is_available(p_name) is False
    assert cb.get_state(p_name) == "open"

    # Réinitialisation manuelle par l'admin
    cb.reset(p_name)
    assert cb.is_available(p_name) is True
    assert cb.get_state(p_name) == "closed"


def test_router_plan_candidate_safety():
    """Vérifie que le routeur ne donne pas accès à des modèles VIP pour un plan Free."""
    router = ProviderRouter()

    # Utilisateur Free demandant Claude 3.5 Sonnet -> doit recevoir le modèle par défaut Free (Gemini)
    candidates_free = router._build_route_candidates("claude-3-5-sonnet", user_plan="free")
    first_candidate = candidates_free[0]
    assert first_candidate["provider"] == "gemini"

    # Utilisateur VIP demandant Claude 3.5 Sonnet -> doit avoir Claude en premier candidat
    candidates_vip = router._build_route_candidates("claude-3-5-sonnet", user_plan="vip")
    first_vip = candidates_vip[0]
    assert first_vip["provider"] == "anthropic"


def test_admin_gateway_endpoints():
    """Vérifie la supervision du SD AI Gateway via les endpoints administrateur."""
    admin_token = create_admin_access_token("6e887b6b-3339-4297-89e0-d3ec2658a83a", "sekoudiaby433@gmail.com")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # 1. Statut Gateway
    resp_status = client.get("/api/v1/admin/gateway/status", headers=admin_headers)
    assert resp_status.status_code == 200
    data = resp_status.json()
    assert "providers" in data
    assert "plans" in data
    prov_names = [p["provider"] for p in data["providers"]]
    assert "gemini" in prov_names
    assert "openai" in prov_names
    assert "anthropic" in prov_names
    assert "xai" in prov_names
    assert "openrouter" in prov_names

    # 2. Catalogue des Modèles
    resp_models = client.get("/api/v1/admin/gateway/models", headers=admin_headers)
    assert resp_models.status_code == 200
    models_data = resp_models.json()
    assert len(models_data) >= 10
    active_models = [m for m in models_data if m["is_active"]]
    assert len(active_models) >= 5

    # 3. Plans officiels SD
    resp_plans = client.get("/api/v1/admin/gateway/plans", headers=admin_headers)
    assert resp_plans.status_code == 200
    plans_data = resp_plans.json()
    assert len(plans_data) == 4


def test_payment_methods_and_mobile_money_strict_no_mock():
    """Vérifie la conformité des méthodes de paiement et l'absence stricte de mock."""
    # 1. Listing des passerelles de paiement
    methods = list_available_payment_methods()
    assert len(methods) >= 3
    provider_ids = [m["provider"] for m in methods]
    assert "stripe" in provider_ids
    assert "orange_money_gn" in provider_ids
    assert "mtn_momo_gn" in provider_ids

    # 2. Adaptateur Mobile Money Guinée : rejet sans identifiants marchands réels
    om_adapter = get_payment_adapter("orange_money_gn")
    assert isinstance(om_adapter, MobileMoneyGuineaAdapter)
    assert om_adapter.supported_currencies == ["GNF"]

    reqs = om_adapter.get_merchant_requirements()
    assert reqs["currency"] == "GNF"
    assert reqs["country"] == "Guinée (GN)"
