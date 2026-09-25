import io
import uuid
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.rate_limiter import rate_limiter

client = TestClient(app)

SESSION_SUFFIX = uuid.uuid4().hex[:6]
USER_A_ID = f"sec-user-a-{SESSION_SUFFIX}"
USER_B_ID = f"sec-user-b-{SESSION_SUFFIX}"

AUTH_USER_A = {"Authorization": f"Bearer dev-token-{USER_A_ID}"}
AUTH_USER_B = {"Authorization": f"Bearer dev-token-{USER_B_ID}"}


def test_security_headers_present():
    """Vérifie que les en-têtes HTTP de sécurité OWASP sont injectés dans les réponses."""
    response = client.get("/")
    assert response.status_code == 200
    assert response.headers.get("X-Content-Type-Options") == "nosniff"
    assert response.headers.get("X-Frame-Options") == "DENY"
    assert "1; mode=block" in response.headers.get("X-XSS-Protection", "")
    assert response.headers.get("Referrer-Policy") == "strict-origin-when-cross-origin"


def test_idor_cross_tenant_conversation_isolation():
    """Vérifie qu'un utilisateur ne peut ni lire, ni modifier, ni supprimer les conversations d'un autre utilisateur."""
    # 1. User A crée une conversation
    create_res = client.post(
        "/api/v1/conversations",
        headers=AUTH_USER_A,
        json={"title": "Projet Confidentiel A", "model": "gemini-3.6-flash"}
    )
    assert create_res.status_code == 201
    conv_id = create_res.json()["id"]

    # 2. User B tente de lire la conversation de User A -> Doit être rejeté (404)
    read_res = client.get(f"/api/v1/conversations/{conv_id}", headers=AUTH_USER_B)
    assert read_res.status_code == 404

    # 3. User B tente de renommer la discussion de User A -> Rejeté (404)
    patch_res = client.patch(
        f"/api/v1/conversations/{conv_id}",
        headers=AUTH_USER_B,
        json={"title": "Piratage Titre B"}
    )
    assert patch_res.status_code == 404

    # 4. User B tente de supprimer la conversation de User A -> Rejeté (404)
    del_res = client.delete(f"/api/v1/conversations/{conv_id}", headers=AUTH_USER_B)
    assert del_res.status_code == 404

    # 5. User A peut toujours accéder à sa propre conversation
    read_owner = client.get(f"/api/v1/conversations/{conv_id}", headers=AUTH_USER_A)
    assert read_owner.status_code == 200
    assert read_owner.json()["conversation"]["title"] == "Projet Confidentiel A"


def test_idor_cross_tenant_attachment_isolation():
    """Vérifie l'isolation stricte des pièces jointes et empêche le rattachement frauduleux."""
    # 1. User A crée sa conversation
    create_conv = client.post(
        "/api/v1/conversations",
        headers=AUTH_USER_A,
        json={"title": "Fichiers Confidentiels A"}
    )
    conv_a_id = create_conv.json()["id"]

    # 2. User B tente d'uploader un fichier en le liant à la conversation de User A -> Rejeté (404)
    file_payload = {"file": ("test.txt", io.BytesIO(b"Donnees de test B"), "text/plain")}
    cross_upload = client.post(
        "/api/v1/attachments/upload",
        headers=AUTH_USER_B,
        data={"conversation_id": conv_a_id},
        files=file_payload,
    )
    assert cross_upload.status_code == 404

    # 3. User A uploade un fichier légitime
    file_owner = {"file": ("secret_alpha.txt", io.BytesIO(b"Secret confidentiel Alpha"), "text/plain")}
    up_res = client.post(
        "/api/v1/attachments/upload",
        headers=AUTH_USER_A,
        data={"conversation_id": conv_a_id},
        files=file_owner,
    )
    assert up_res.status_code == 201
    att_id = up_res.json()["id"]

    # 4. User B tente de consulter les métadonnées de la pièce jointe de User A -> Rejeté (404)
    meta_res = client.get(f"/api/v1/attachments/{att_id}", headers=AUTH_USER_B)
    assert meta_res.status_code == 404

    # 5. User B tente de télécharger le contenu binaire brut de la pièce jointe de User A -> Rejeté (404)
    raw_res = client.get(f"/api/v1/attachments/{att_id}/raw", headers=AUTH_USER_B)
    assert raw_res.status_code == 404

    # 6. User B tente de supprimer la pièce jointe de User A -> Rejeté (404)
    del_res = client.delete(f"/api/v1/attachments/{att_id}", headers=AUTH_USER_B)
    assert del_res.status_code == 404

    # 7. User A peut récupérer son propre fichier
    raw_owner = client.get(f"/api/v1/attachments/{att_id}/raw", headers=AUTH_USER_A)
    assert raw_owner.status_code == 200
    assert raw_owner.content == b"Secret confidentiel Alpha"


def test_filename_sanitization_path_traversal():
    """Vérifie que les tentatives de Path Traversal dans le nom de fichier sont neutralisées."""
    auth_sanit = {"Authorization": "Bearer dev-token-sec-user-sanit-999"}
    dangerous_filename = "../../../etc/passwd"
    payload = {"file": (dangerous_filename, io.BytesIO(b"root:x:0:0"), "text/plain")}
    res = client.post(
        "/api/v1/attachments/upload",
        headers=auth_sanit,
        files=payload,
    )
    assert res.status_code == 201
    safe_stored_name = res.json()["file_name"]
    # Le nom ne doit contenir aucun séparateur de répertoire
    assert "/" not in safe_stored_name
    assert "\\" not in safe_stored_name
    assert ".." not in safe_stored_name


def test_admin_vs_normal_user_access_control():
    """Vérifie qu'un utilisateur standard ne peut accéder à aucun endpoint d'administration."""
    # User standard tente d'accéder aux statistiques admin -> 403 Forbidden
    res_stats = client.get("/api/v1/admin/stats", headers=AUTH_USER_A)
    assert res_stats.status_code == 403

    # User standard tente d'accéder à la liste des utilisateurs admin -> 403 Forbidden
    res_users = client.get("/api/v1/admin/users", headers=AUTH_USER_A)
    assert res_users.status_code == 403

    # User standard tente d'accéder aux analytics admin -> 403 Forbidden
    res_analytics = client.get("/api/v1/admin/analytics", headers=AUTH_USER_A)
    assert res_analytics.status_code == 403

    # Sans aucun jeton d'authentification -> 401 Unauthorized
    res_no_auth = client.get("/api/v1/admin/stats")
    assert res_no_auth.status_code == 401


def test_input_validation_oversized_payload_rejected():
    """Vérifie que les messages dépassant la limite de 50 000 caractères sont rejetés (422)."""
    oversized_text = "A" * 50001
    res = client.post(
        "/api/v1/chat/stream",
        headers=AUTH_USER_A,
        json={"content": oversized_text}
    )
    assert res.status_code == 422


def test_rate_limiter_blocks_excessive_requests():
    """Vérifie que le RateLimiter bloque les rafales de requêtes excessives et renvoie HTTP 429."""
    dummy_ip = "192.0.2.99"
    endpoint = "/api/v1/admin/auth/login"

    # La règle pour admin login est 5 requêtes par minute
    # Simuler 5 appels
    for _ in range(5):
        allowed, _ = rate_limiter.is_allowed(dummy_ip, endpoint)
        assert allowed is True

    # Le 6ème appel doit être rejeté
    allowed, retry_after = rate_limiter.is_allowed(dummy_ip, endpoint)
    assert allowed is False
    assert retry_after > 0
