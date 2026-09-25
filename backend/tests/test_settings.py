import uuid
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.database.connection import db_manager
from app.repositories.chat_repository import ChatRepository

client = TestClient(app)


def test_user_profile_get_and_patch():
    test_uid = f"test-settings-user-{uuid.uuid4().hex[:8]}"
    headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    # 1. Obtenir le profil
    resp_get = client.get("/api/v1/profile", headers=headers)
    assert resp_get.status_code == 200
    data = resp_get.json()
    assert data["id"] == test_uid
    assert data["tier"] == "free"

    # 2. Mettre à jour le profil (nom et préférences)
    resp_patch = client.patch(
        "/api/v1/profile",
        headers=headers,
        json={
            "full_name": "Sekou Diaby Tester",
            "preferences": {
                "theme": "dark",
                "language": "fr",
                "accent_color": "#E5A93C",
                "font_scale": 1.15
            }
        }
    )
    assert resp_patch.status_code == 200
    updated = resp_patch.json()
    assert updated["full_name"] == "Sekou Diaby Tester"
    assert updated["preferences"]["language"] == "fr"
    assert updated["preferences"]["accent_color"] == "#E5A93C"

    # Nettoyage
    with db_manager.connect() as conn:
        conn.run("DELETE FROM public.profiles WHERE id = :uid", uid=test_uid)


def test_avatar_upload_and_validation():
    test_uid = f"test-avatar-user-{uuid.uuid4().hex[:8]}"
    headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    # 1. Fichier invalide (non-image)
    resp_bad = client.post(
        "/api/v1/profile/avatar",
        headers=headers,
        files={"file": ("test.pdf", b"%PDF-fake", "application/pdf")}
    )
    assert resp_bad.status_code == 400

    # 2. Image JPEG valide
    fake_jpeg = b"\xff\xd8\xff\xe0\x00\x10JFIF" + b"A" * 100
    resp_ok = client.post(
        "/api/v1/profile/avatar",
        headers=headers,
        files={"file": ("avatar.jpg", fake_jpeg, "image/jpeg")}
    )
    assert resp_ok.status_code == 200
    data = resp_ok.json()
    assert data["success"] is True
    assert "avatar_url" in data
    assert data["avatar_url"].startswith("data:image/jpeg;base64,")

    # Nettoyage
    with db_manager.connect() as conn:
        conn.run("DELETE FROM public.profiles WHERE id = :uid", uid=test_uid)


def test_shared_conversations_flow():
    test_uid = f"test-share-user-{uuid.uuid4().hex[:8]}"
    headers = {"Authorization": f"Bearer dev-token-{test_uid}"}
    ChatRepository.ensure_user_profile(test_uid)

    # Créer une discussion et un message
    conv = ChatRepository.create_conversation(user_id=test_uid, title="Discussion de test partage")
    cid = conv["id"]
    ChatRepository.save_message(cid, test_uid, "user", "Bonjour, ceci est un test de partage.")
    ChatRepository.save_message(cid, test_uid, "assistant", "Réponse partagée avec succès.")

    # 1. Créer le lien de partage
    resp_share = client.post(f"/api/v1/conversations/{cid}/share", headers=headers)
    assert resp_share.status_code == 201
    share_data = resp_share.json()
    share_token = share_data["share_token"]
    share_id = share_data["id"]
    assert share_data["is_revoked"] is False

    # 2. Consulter publiquement sans authentification
    resp_pub = client.get(f"/api/v1/conversations/public/{share_token}")
    assert resp_pub.status_code == 200
    pub_data = resp_pub.json()
    assert pub_data["title"] == "Discussion de test partage"
    assert len(pub_data["messages"]) == 2

    # 3. Lister les liens partagés de l'utilisateur
    resp_list = client.get("/api/v1/conversations/shared/links", headers=headers)
    assert resp_list.status_code == 200
    links = resp_list.json()
    assert len(links) >= 1
    assert any(l["id"] == share_id for l in links)

    # 4. Révoquer le lien partagé
    resp_revoke = client.delete(f"/api/v1/conversations/shared/{share_id}", headers=headers)
    assert resp_revoke.status_code == 200
    assert resp_revoke.json()["is_revoked"] is True

    # 5. La consultation publique doit maintenant échouer (HTTP 410 Gone)
    resp_pub_revoked = client.get(f"/api/v1/conversations/public/{share_token}")
    assert resp_pub_revoked.status_code == 410

    # Nettoyage
    with db_manager.connect() as conn:
        conn.run("DELETE FROM public.shared_conversations WHERE user_id = :uid", uid=test_uid)
        conn.run("DELETE FROM public.chat_messages WHERE user_id = :uid", uid=test_uid)
        conn.run("DELETE FROM public.chat_conversations WHERE user_id = :uid", uid=test_uid)
        conn.run("DELETE FROM public.profiles WHERE id = :uid", uid=test_uid)


def test_data_control_cloud_deletion_and_account_deletion():
    test_uid = f"test-delete-user-{uuid.uuid4().hex[:8]}"
    headers = {"Authorization": f"Bearer dev-token-{test_uid}"}
    ChatRepository.ensure_user_profile(test_uid)

    # Créer 2 conversations
    ChatRepository.create_conversation(user_id=test_uid, title="Disc 1")
    ChatRepository.create_conversation(user_id=test_uid, title="Disc 2")

    # 1. Supprimer les données cloud
    resp_cloud = client.delete("/api/v1/data/cloud", headers=headers)
    assert resp_cloud.status_code == 200
    cloud_data = resp_cloud.json()
    assert cloud_data["success"] is True
    assert cloud_data["deleted_conversations_count"] >= 2

    # Vérifier que le profil existe toujours
    resp_profile = client.get("/api/v1/profile", headers=headers)
    assert resp_profile.status_code == 200

    # 2. Supprimer définitivement le compte
    resp_account = client.delete("/api/v1/users/me", headers=headers)
    assert resp_account.status_code == 200
    assert resp_account.json()["success"] is True

    # Vérifier que la table profile a bien été nettoyée
    with db_manager.connect() as conn:
        rows = conn.run("SELECT id FROM public.profiles WHERE id = :uid", uid=test_uid)
        assert len(rows) == 0


def test_support_feedback_and_version_check():
    test_uid = f"test-feedback-user-{uuid.uuid4().hex[:8]}"
    headers = {"Authorization": f"Bearer dev-token-{test_uid}"}

    # 1. Envoi de feedback / support
    resp_feedback = client.post(
        "/api/v1/support/feedback",
        headers=headers,
        json={
            "category": "bug",
            "subject": "Problème d'affichage sur écran AMOLED",
            "description": "Les contrastes sont excellents mais j'aimerais signaler une suggestion de couleur.",
            "email": "utilisateur.test@sd-chat.ai",
            "device_info": {"model": "Pixel 8", "android_version": "14"}
        }
    )
    assert resp_feedback.status_code == 201
    fb_data = resp_feedback.json()
    assert "ticket_id" in fb_data
    assert fb_data["status"] == "received"
    assert "sd.ai.founder@gmail.com" in fb_data["message"]

    # 2. Vérification de version de l'application
    resp_version = client.get("/api/v1/app/version-check?current_version=1.0.0")
    assert resp_version.status_code == 200
    v_data = resp_version.json()
    assert v_data["current_version"] == "1.0.0"
    assert v_data["latest_version"] == "1.0.0"
    assert v_data["is_update_available"] is False
    assert "com.sd.chat.sd_chat_ai" in v_data["play_store_url"]

    # Nettoyage feedback
    with db_manager.connect() as conn:
        conn.run("DELETE FROM public.user_feedback WHERE subject = 'Problème d''affichage sur écran AMOLED'")
