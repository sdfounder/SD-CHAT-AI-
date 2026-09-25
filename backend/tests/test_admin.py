import uuid
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.database.connection import db_manager
from app.repositories.chat_repository import ChatRepository
from app.core.security import create_admin_access_token
from app.services.quota_service import QuotaService, FREE_DAILY_MESSAGES_LIMIT, PREMIUM_DAILY_MESSAGES_LIMIT
from app.services.admin_service import AdminService

client = TestClient(app)


def test_admin_dashboard_web_html_served():
    """Vérifie que la page web /admin est servie correctement avec l'interface moderne."""
    resp = client.get("/admin")
    assert resp.status_code == 200
    assert "text/html" in resp.headers["content-type"]
    assert "SD CHAT AI" in resp.text
    assert "Connexion Administrateur" in resp.text
    assert "Vue d'ensemble" in resp.text


def test_admin_login_invalid_credentials():
    """Vérifie que les mauvaises informations d'identification sont rejetées avec HTTP 401."""
    resp = client.post(
        "/api/v1/admin/auth/login",
        json={"email": "wrong@admin.com", "password": "wrongpassword123"}
    )
    assert resp.status_code == 401


def test_admin_login_valid_credentials():
    """Vérifie l'authentification admin avec les identifiants officiels."""
    creds = AdminService._read_admin_secret_file()
    resp = client.post(
        "/api/v1/admin/auth/login",
        json={"email": creds["email"], "password": creds["password"]}
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["admin"]["role"] == "admin"
    assert data["admin"]["email"] == creds["email"]


def test_admin_access_control_unauthenticated_and_non_admin():
    """
    Vérifie le contrôle d'accès strict :
    - Non authentifié -> HTTP 401
    - Utilisateur standard (non admin) -> HTTP 403
    """
    # 1. Non authentifié
    resp_unauth = client.get("/api/v1/admin/stats")
    assert resp_unauth.status_code == 401

    # 2. Utilisateur standard
    test_user_uid = f"standard-user-{uuid.uuid4().hex[:8]}"
    ChatRepository.ensure_user_profile(test_user_uid, email=f"{test_user_uid}@sd-chat.ai")
    user_headers = {"Authorization": f"Bearer dev-token-{test_user_uid}"}

    resp_forbidden = client.get("/api/v1/admin/stats", headers=user_headers)
    assert resp_forbidden.status_code == 403
    assert "administrateur" in resp_forbidden.json()["detail"].lower()


def test_admin_stats_and_users_listing():
    """Vérifie la récupération des métriques consolidées et de la liste des utilisateurs."""
    admin_token = create_admin_access_token("6e887b6b-3339-4297-89e0-d3ec2658a83a", "sekoudiaby433@gmail.com")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # 1. Statistiques
    resp_stats = client.get("/api/v1/admin/stats", headers=admin_headers)
    assert resp_stats.status_code == 200
    stats = resp_stats.json()
    assert "total_users" in stats
    assert stats["total_users"] >= 1
    assert "total_conversations" in stats
    assert "total_messages" in stats
    assert "free_users_count" in stats
    assert "premium_users_count" in stats
    assert "stripe_active_subscriptions" in stats
    assert "stripe_mrr_eur" in stats

    # 2. Liste des utilisateurs
    resp_users = client.get("/api/v1/admin/users?limit=10", headers=admin_headers)
    assert resp_users.status_code == 200
    users_data = resp_users.json()
    assert "users" in users_data
    assert "total_count" in users_data
    assert len(users_data["users"]) >= 1


def test_admin_user_suspension_and_reactivation_lifecycle():
    """
    Teste le cycle complet de suspension/réactivation :
    1. Création d'un utilisateur de test
    2. Vérification que l'utilisateur peut appeler l'API (/api/v1/quota -> 200)
    3. Suspension par l'administrateur
    4. Vérification que l'utilisateur est strictement bloqué avec HTTP 403 (compte suspendu)
    5. Réactivation par l'administrateur
    6. Vérification que l'utilisateur a de nouveau accès (HTTP 200)
    """
    admin_token = create_admin_access_token("6e887b6b-3339-4297-89e0-d3ec2658a83a", "sekoudiaby433@gmail.com")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    test_uid = f"user-suspension-test-{uuid.uuid4().hex[:8]}"
    ChatRepository.ensure_user_profile(test_uid, email=f"{test_uid}@sd-chat.ai")
    user_headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    try:
        # 1. L'utilisateur actif peut accéder à ses quotas
        resp_quota_ok = client.get("/api/v1/quota", headers=user_headers)
        assert resp_quota_ok.status_code == 200

        # 2. Suspension par l'administrateur
        resp_suspend = client.post(
            f"/api/v1/admin/users/{test_uid}/status",
            headers=admin_headers,
            json={"is_suspended": True, "reason": "Test unitaire de suspension administrative"}
        )
        assert resp_suspend.status_code == 200
        assert resp_suspend.json()["is_suspended"] is True

        # 3. L'utilisateur suspendu doit être rejeté avec HTTP 403
        resp_blocked = client.get("/api/v1/quota", headers=user_headers)
        assert resp_blocked.status_code == 403
        assert "suspendu" in resp_blocked.json()["detail"].lower()

        # 4. Réactivation par l'administrateur
        resp_reactivate = client.post(
            f"/api/v1/admin/users/{test_uid}/status",
            headers=admin_headers,
            json={"is_suspended": False, "reason": "Levée de suspension"}
        )
        assert resp_reactivate.status_code == 200
        assert resp_reactivate.json()["is_suspended"] is False

        # 5. L'utilisateur peut à nouveau utiliser le service
        resp_quota_restored = client.get("/api/v1/quota", headers=user_headers)
        assert resp_quota_restored.status_code == 200

    finally:
        # Nettoyage
        with db_manager.connect() as conn:
            conn.run("DELETE FROM public.profiles WHERE id = :uid", uid=test_uid)


def test_admin_user_tier_manual_adjustment():
    """
    Vérifie qu'un administrateur peut modifier la formule d'un utilisateur (Free -> Premium -> Free)
    et que les quotas s'adaptent immédiatement (20 -> 500 -> 20).
    """
    admin_token = create_admin_access_token("6e887b6b-3339-4297-89e0-d3ec2658a83a", "sekoudiaby433@gmail.com")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    test_uid = f"user-tier-test-{uuid.uuid4().hex[:8]}"
    ChatRepository.ensure_user_profile(test_uid, email=f"{test_uid}@sd-chat.ai")
    user_headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    try:
        # 1. Quota initial Free (20 messages)
        q_init = client.get("/api/v1/quota", headers=user_headers).json()
        assert q_init["plan"] == "free"
        assert q_init["messages_limit"] == FREE_DAILY_MESSAGES_LIMIT

        # 2. Passage en Premium par l'admin
        resp_prem = client.post(
            f"/api/v1/admin/users/{test_uid}/tier",
            headers=admin_headers,
            json={"tier": "premium"}
        )
        assert resp_prem.status_code == 200
        assert resp_prem.json()["tier"] == "premium"

        # 3. Vérification des quotas Premium immédiats (500 messages)
        q_prem = client.get("/api/v1/quota", headers=user_headers).json()
        assert q_prem["plan"] == "premium"
        assert q_prem["is_premium"] is True
        assert q_prem["messages_limit"] == PREMIUM_DAILY_MESSAGES_LIMIT

        # 4. Rétrogradation en Free par l'admin
        resp_free = client.post(
            f"/api/v1/admin/users/{test_uid}/tier",
            headers=admin_headers,
            json={"tier": "free"}
        )
        assert resp_free.status_code == 200
        assert resp_free.json()["tier"] == "free"

        # 5. Vérification du retour au plan Free
        q_back = client.get("/api/v1/quota", headers=user_headers).json()
        assert q_back["plan"] == "free"
        assert q_back["is_premium"] is False
        assert q_back["messages_limit"] == FREE_DAILY_MESSAGES_LIMIT

    finally:
        with db_manager.connect() as conn:
            conn.run("DELETE FROM public.subscriptions WHERE user_id = :uid", uid=test_uid)
            conn.run("DELETE FROM public.profiles WHERE id = :uid", uid=test_uid)


def test_admin_providers_and_quotas_configuration():
    """Vérifie la consultation des providers IA et la mise à jour des paramètres de quotas."""
    admin_token = create_admin_access_token("6e887b6b-3339-4297-89e0-d3ec2658a83a", "sekoudiaby433@gmail.com")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # 1. Consultation des providers IA
    resp_prov = client.get("/api/v1/admin/ai/providers", headers=admin_headers)
    assert resp_prov.status_code == 200
    providers = resp_prov.json()
    assert len(providers) >= 2
    gemini = next(p for p in providers if p["provider_type"] == "gemini")
    sd_core = next(p for p in providers if p["provider_type"] == "sd_core")

    assert gemini["is_active"] is True
    assert "..." in gemini["masked_api_key"]  # Clé masquée
    assert sd_core["provider_type"] == "sd_core"

    # 2. Quotas globaux : GET puis PATCH
    resp_q_get = client.get("/api/v1/admin/ai/quotas", headers=admin_headers)
    assert resp_q_get.status_code == 200

    resp_q_patch = client.patch(
        "/api/v1/admin/ai/quotas",
        headers=admin_headers,
        json={
            "free_messages_limit": 25,
            "free_attachments_limit": 5,
            "premium_messages_limit": 600,
            "premium_attachments_limit": 60,
            "max_attachment_size_mb": 15,
        }
    )
    assert resp_q_patch.status_code == 200
    updated_q = resp_q_patch.json()
    assert updated_q["free_messages_limit"] == 25
    assert updated_q["premium_messages_limit"] == 600

    # Rétablir les valeurs par défaut
    client.patch(
        "/api/v1/admin/ai/quotas",
        headers=admin_headers,
        json={
            "free_messages_limit": 20,
            "free_attachments_limit": 3,
            "premium_messages_limit": 500,
            "premium_attachments_limit": 50,
            "max_attachment_size_mb": 10,
        }
    )


def test_admin_audit_logs_traceability():
    """Vérifie que les actions d'administration sont bien tracées dans la piste d'audit."""
    admin_token = create_admin_access_token("6e887b6b-3339-4297-89e0-d3ec2658a83a", "sekoudiaby433@gmail.com")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    resp_audit = client.get("/api/v1/admin/logs/audit?limit=10", headers=admin_headers)
    assert resp_audit.status_code == 200
    logs = resp_audit.json()
    assert isinstance(logs, list)
    # Les actions précédentes doivent avoir généré des entrées d'audit
    actions = [l["action"] for l in logs]
    assert any(a in ("ADMIN_LOGIN", "SUSPEND_USER", "UNSUSPEND_USER", "CHANGE_USER_TIER", "UPDATE_QUOTA_SETTINGS") for a in actions)


def test_admin_auth_status_endpoint():
    """Vérifie le point de terminaison de statut d'inscription/initialisation de l'administrateur."""
    resp = client.get("/api/v1/admin/auth/status")
    assert resp.status_code == 200
    data = resp.json()
    assert "has_admin" in data
    assert "registration_open" in data
    assert data["has_admin"] in (True, False)
    assert data["registration_open"] == (not data["has_admin"])


def test_admin_user_blocking_and_suspension_with_duration():
    """Vérifie le blocage permanent, la suspension temporaire avec motif et la réactivation."""
    admin_token = create_admin_access_token("6e887b6b-3339-4297-89e0-d3ec2658a83a", "sekoudiaby433@gmail.com")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    test_uid = f"block-test-{uuid.uuid4().hex[:8]}"
    ChatRepository.ensure_user_profile(test_uid, email=f"{test_uid}@sd-chat.ai")
    user_headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    try:
        # 1. Utilisateur actif accède normalement
        resp_q = client.get("/api/v1/quota", headers=user_headers)
        assert resp_q.status_code == 200

        # 2. Suspension temporaire (durée 24h + motif)
        resp_susp = client.post(
            f"/api/v1/admin/users/{test_uid}/suspend",
            headers=admin_headers,
            json={"duration_hours": 24, "reason": "Activité suspecte détectée"},
        )
        assert resp_susp.status_code == 200
        assert resp_susp.json()["status"] == "suspended"

        # L'utilisateur doit recevoir HTTP 403 avec mention de la date et du motif
        resp_forbidden_susp = client.get("/api/v1/quota", headers=user_headers)
        assert resp_forbidden_susp.status_code == 403
        assert "suspendu" in resp_forbidden_susp.json()["detail"].lower()
        assert "Activité suspecte" in resp_forbidden_susp.json()["detail"]

        # 3. Blocage définitif avec motif obligatoire
        resp_block = client.post(
            f"/api/v1/admin/users/{test_uid}/block",
            headers=admin_headers,
            json={"reason": "Violation grave des conditions d'utilisation"},
        )
        assert resp_block.status_code == 200
        assert resp_block.json()["status"] == "blocked"

        # L'utilisateur doit recevoir HTTP 403 avec mention du blocage définitif
        resp_forbidden_block = client.get("/api/v1/quota", headers=user_headers)
        assert resp_forbidden_block.status_code == 403
        assert "bloqué" in resp_forbidden_block.json()["detail"].lower()
        assert "Violation grave" in resp_forbidden_block.json()["detail"]

        # 4. Réactivation (Unblock)
        resp_unblock = client.post(f"/api/v1/admin/users/{test_uid}/unblock", headers=admin_headers)
        assert resp_unblock.status_code == 200
        assert resp_unblock.json()["status"] == "active"

        # L'accès est de nouveau autorisé
        resp_ok = client.get("/api/v1/quota", headers=user_headers)
        assert resp_ok.status_code == 200

    finally:
        with db_manager.connect() as conn:
            conn.run("DELETE FROM public.profiles WHERE id = :uid", uid=test_uid)


def test_admin_feedback_management_and_reply():
    """Vérifie le cycle de traitement d'un retour utilisateur : soumission, consultation, réponse avec notification."""
    admin_token = create_admin_access_token("6e887b6b-3339-4297-89e0-d3ec2658a83a", "sekoudiaby433@gmail.com")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    test_uid = f"fb-user-{uuid.uuid4().hex[:8]}"
    ChatRepository.ensure_user_profile(test_uid, email=f"{test_uid}@sd-chat.ai")
    user_headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    feedback_id = None
    try:
        # 1. Utilisateur soumet un feedback
        resp_submit = client.post(
            "/api/v1/support/feedback",
            headers=user_headers,
            json={
                "category": "bug",
                "subject": "Problème d'affichage en mode sombre",
                "description": "Le texte est difficilement lisible sur les bulles.",
            },
        )
        assert resp_submit.status_code == 201
        feedback_id = resp_submit.json()["ticket_id"]

        # 2. Administrateur consulte les feedbacks
        resp_list = client.get("/api/v1/admin/feedback?status=pending", headers=admin_headers)
        assert resp_list.status_code == 200
        fb_data = resp_list.json()
        assert "feedback" in fb_data
        matching = [f for f in fb_data["feedback"] if f["id"] == feedback_id]
        assert len(matching) == 1
        assert matching[0]["category"] == "bug"

        # 3. Administrateur répond au feedback
        resp_reply = client.post(
            f"/api/v1/admin/feedback/{feedback_id}/reply",
            headers=admin_headers,
            json={"reply": "Merci pour le retour, nous avons déployé un correctif pour le contraste sombre."},
        )
        assert resp_reply.status_code == 200
        assert resp_reply.json()["status"] == "resolved"

        # 4. Vérifier que la notification in-app a été créée pour l'utilisateur
        with db_manager.connect() as conn:
            notifs = conn.run(
                "SELECT title, body, type FROM public.notifications WHERE user_id = :uid",
                uid=test_uid
            )
            assert len(notifs) >= 1
            assert notifs[0][2] == "feedback_reply"

    finally:
        with db_manager.connect() as conn:
            if feedback_id:
                conn.run("DELETE FROM public.user_feedback WHERE id = :fid::uuid", fid=feedback_id)
            conn.run("DELETE FROM public.notifications WHERE user_id = :uid", uid=test_uid)
            conn.run("DELETE FROM public.profiles WHERE id = :uid", uid=test_uid)


def test_admin_alerts_and_system_settings():
    """Vérifie la consultation des alertes en temps réel et la modification des paramètres système."""
    admin_token = create_admin_access_token("6e887b6b-3339-4297-89e0-d3ec2658a83a", "sekoudiaby433@gmail.com")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # 1. Alertes système
    resp_alerts = client.get("/api/v1/admin/alerts", headers=admin_headers)
    assert resp_alerts.status_code == 200
    alerts_data = resp_alerts.json()
    assert "alerts" in alerts_data
    assert "total_unread" in alerts_data

    # 2. Paramètres système
    resp_settings = client.get("/api/v1/admin/settings", headers=admin_headers)
    assert resp_settings.status_code == 200
    settings_data = resp_settings.json()
    assert "settings" in settings_data

    # 3. Modification d'un paramètre
    resp_patch = client.patch(
        "/api/v1/admin/settings",
        headers=admin_headers,
        json={
            "key": "min_app_version",
            "value": {"version": "1.0.5", "force_update": False},
        },
    )
    assert resp_patch.status_code == 200
    assert resp_patch.json()["key"] == "min_app_version"


def test_admin_gateway_plan_update():
    """Vérifie la mise à jour des limites d'un plan SD officiel."""
    admin_token = create_admin_access_token("6e887b6b-3339-4297-89e0-d3ec2658a83a", "sekoudiaby433@gmail.com")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    resp_patch = client.patch(
        "/api/v1/admin/gateway/plans/free",
        headers=admin_headers,
        json={"ai_queries_limit": 8, "ocr_pages_limit": 2},
    )
    assert resp_patch.status_code == 200
    assert resp_patch.json()["plan_id"] == "free"

    # Rétablir les limites initiales
    client.patch(
        "/api/v1/admin/gateway/plans/free",
        headers=admin_headers,
        json={"ai_queries_limit": 5, "ocr_pages_limit": 1},
    )

