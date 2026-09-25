import io
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)
AUTH_HEADERS = {"Authorization": "Bearer dev-token-00000000-0000-0000-0000-000000000001"}


def test_attachment_security_unauthenticated():
    response = client.post(
        "/api/v1/attachments/upload",
        files={"file": ("note.txt", b"Hello", "text/plain")}
    )
    assert response.status_code == 401


def test_attachment_upload_empty_file():
    response = client.post(
        "/api/v1/attachments/upload",
        headers=AUTH_HEADERS,
        files={"file": ("empty.txt", b"", "text/plain")}
    )
    assert response.status_code == 400
    assert "vide" in response.json()["detail"].lower()


def test_attachment_upload_invalid_format():
    response = client.post(
        "/api/v1/attachments/upload",
        headers=AUTH_HEADERS,
        files={"file": ("malware.exe", b"binary content", "application/x-msdownload")}
    )
    assert response.status_code == 400
    assert "non pris en charge" in response.json()["detail"].lower()


def test_attachment_upload_too_large():
    # Taille limite = 10 Mo
    eleven_mb = b"0" * (10 * 1024 * 1024 + 1024)
    response = client.post(
        "/api/v1/attachments/upload",
        headers=AUTH_HEADERS,
        files={"file": ("huge.txt", eleven_mb, "text/plain")}
    )
    assert response.status_code == 413
    assert "10 mo" in response.json()["detail"].lower()


def test_attachment_lifecycle_txt_and_image():
    from app.database.connection import db_manager
    with db_manager.connect() as conn:
        conn.run(
            "DELETE FROM public.chat_user_usage WHERE user_id = '00000000-0000-0000-0000-000000000001'"
        )

    # 1. Upload d'un fichier texte TXT valide
    txt_content = b"Voici un document de test pour SD CHAT AI Mission 5."
    response = client.post(
        "/api/v1/attachments/upload",
        headers=AUTH_HEADERS,
        files={"file": ("notes.txt", txt_content, "text/plain")}
    )
    assert response.status_code == 201
    txt_data = response.json()
    assert txt_data["file_name"] == "notes.txt"
    assert txt_data["file_type"] == "text"
    assert txt_data["mime_type"] == "text/plain"
    assert txt_data["file_size_bytes"] == len(txt_content)
    att_id = txt_data["id"]

    # 2. Récupération des métadonnées
    meta_resp = client.get(f"/api/v1/attachments/{att_id}", headers=AUTH_HEADERS)
    assert meta_resp.status_code == 200
    assert meta_resp.json()["id"] == att_id

    # 3. Récupération du contenu binaire brut
    raw_resp = client.get(f"/api/v1/attachments/{att_id}/raw", headers=AUTH_HEADERS)
    assert raw_resp.status_code == 200
    assert raw_resp.content == txt_content
    assert "text/plain" in raw_resp.headers["content-type"]

    # 4. Upload d'une image PNG valide (1x1 transparent PNG)
    png_bytes = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
        b"\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05"
        b"\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    img_resp = client.post(
        "/api/v1/attachments/upload",
        headers=AUTH_HEADERS,
        files={"file": ("photo.png", png_bytes, "image/png")}
    )
    assert img_resp.status_code == 201
    img_data = img_resp.json()
    assert img_data["file_name"] == "photo.png"
    assert img_data["file_type"] == "image"
    img_id = img_data["id"]

    # 5. Créer une conversation et vérifier que le message lie les pièces jointes
    conv_resp = client.post(
        "/api/v1/conversations",
        headers=AUTH_HEADERS,
        json={"title": "Chat avec pièces jointes"}
    )
    conv_id = conv_resp.json()["id"]

    # Envoyer un message avec attachment_ids
    send_resp = client.post(
        "/api/v1/chat/stream",
        headers=AUTH_HEADERS,
        json={
            "conversation_id": conv_id,
            "content": "Voici mon image et mon texte",
            "attachment_ids": [att_id, img_id]
        }
    )
    assert send_resp.status_code == 200

    # Vérifier que les messages de la conversation contiennent bien les attachments
    detail_resp = client.get(f"/api/v1/conversations/{conv_id}", headers=AUTH_HEADERS)
    assert detail_resp.status_code == 200
    messages = detail_resp.json()["messages"]
    user_msgs = [m for m in messages if m["role"] == "user"]
    assert len(user_msgs) >= 1
    user_att_ids = [a["id"] for a in user_msgs[0]["attachments"]]
    assert att_id in user_att_ids
    assert img_id in user_att_ids

    # 6. Suppression de l'attachment
    del_resp = client.delete(f"/api/v1/attachments/{att_id}", headers=AUTH_HEADERS)
    assert del_resp.status_code == 200

    # 7. Vérifier que la pièce jointe supprimée n'est plus accessible
    get_deleted = client.get(f"/api/v1/attachments/{att_id}", headers=AUTH_HEADERS)
    assert get_deleted.status_code == 404

    # Nettoyage de la conversation
    client.delete(f"/api/v1/conversations/{conv_id}", headers=AUTH_HEADERS)
