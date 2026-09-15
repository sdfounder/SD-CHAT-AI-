import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.ai import get_ai_provider

client = TestClient(app)
AUTH_HEADERS = {"Authorization": "Bearer dev-token-00000000-0000-0000-0000-000000000001"}


def test_root_identity():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["app"] == "SD CHAT AI"
    assert data["creator"] == "Sekou Diaby"
    assert "Build the Future with AI" in data["slogan"]


def test_health_check_database():
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "online"
    assert data["database"] == "connected"
    assert data["ai_provider"] == "gemini"
    assert "gemini" in data["ai_model"]


def test_security_jwt_enforcement():
    # Requête non authentifiée -> 401
    unauth_resp = client.get("/api/v1/conversations")
    assert unauth_resp.status_code == 401


def test_conversation_lifecycle():
    # 1. Créer une discussion
    create_resp = client.post(
        "/api/v1/conversations",
        headers=AUTH_HEADERS,
        json={"title": "Discussion Test Cycle de Vie"}
    )
    assert create_resp.status_code == 201
    conv = create_resp.json()
    conv_id = conv["id"]
    assert conv["title"] == "Discussion Test Cycle de Vie"

    # 2. Lister les discussions
    list_resp = client.get("/api/v1/conversations", headers=AUTH_HEADERS)
    assert list_resp.status_code == 200
    conv_ids = [c["id"] for c in list_resp.json()]
    assert conv_id in conv_ids

    # 3. Mettre à jour le titre
    update_resp = client.patch(
        f"/api/v1/conversations/{conv_id}",
        headers=AUTH_HEADERS,
        json={"title": "Titre Renommé"}
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["title"] == "Titre Renommé"

    # 4. Supprimer
    del_resp = client.delete(f"/api/v1/conversations/{conv_id}", headers=AUTH_HEADERS)
    assert del_resp.status_code == 204

    # 5. Vérifier qu'elle n'existe plus
    get_resp = client.get(f"/api/v1/conversations/{conv_id}", headers=AUTH_HEADERS)
    assert get_resp.status_code == 404


def test_real_gemini_streaming_sse():
    # Créer une conversation
    create_resp = client.post(
        "/api/v1/conversations",
        headers=AUTH_HEADERS,
        json={"title": "Test Streaming SSE"}
    )
    assert create_resp.status_code == 201
    conv_id = create_resp.json()["id"]

    tokens = []
    has_done_event = False

    with client.stream(
        "POST",
        "/api/v1/chat/stream",
        headers=AUTH_HEADERS,
        json={
            "conversation_id": conv_id,
            "content": "Donne un chiffre entre 1 et 9."
        }
    ) as response:
        assert response.status_code == 200
        for line in response.iter_lines():
            if line.startswith("data: "):
                import json
                payload = json.loads(line[6:])
                if payload.get("token"):
                    tokens.append(payload["token"])
                if payload.get("done") is True:
                    has_done_event = True
                    break

    assert len(tokens) >= 1
    assert has_done_event is True

    # Vérifier que le message a été persisté dans la base Supabase
    detail_resp = client.get(f"/api/v1/conversations/{conv_id}", headers=AUTH_HEADERS)
    assert detail_resp.status_code == 200
    messages = detail_resp.json()["messages"]
    assert len(messages) == 2
    assert messages[0]["role"] == "user"
    assert messages[1]["role"] == "assistant"
    assert len(messages[1]["content"]) > 0

    # Nettoyage
    client.delete(f"/api/v1/conversations/{conv_id}", headers=AUTH_HEADERS)


def test_edit_message_and_regenerate():
    # 1. Créer une conversation
    create_resp = client.post(
        "/api/v1/conversations",
        headers=AUTH_HEADERS,
        json={"title": "Test Modification et Régénération"}
    )
    assert create_resp.status_code == 201
    conv_id = create_resp.json()["id"]

    # 2. Envoyer premier message
    with client.stream(
        "POST",
        "/api/v1/chat/stream",
        headers=AUTH_HEADERS,
        json={"conversation_id": conv_id, "content": "Premier message original."}
    ) as r1:
        for _ in r1.iter_lines():
            pass

    # Vérifier 2 messages (user + assistant)
    d1 = client.get(f"/api/v1/conversations/{conv_id}", headers=AUTH_HEADERS).json()
    assert len(d1["messages"]) == 2
    user_msg_id = d1["messages"][0]["id"]
    assert d1["messages"][0]["content"] == "Premier message original."

    # 3. Modifier le premier message et régénérer
    with client.stream(
        "POST",
        "/api/v1/chat/stream",
        headers=AUTH_HEADERS,
        json={
            "conversation_id": conv_id,
            "content": "Message modifié avec succès.",
            "edit_message_id": user_msg_id
        }
    ) as r2:
        for _ in r2.iter_lines():
            pass

    # Vérifier que le message utilisateur a été mis à jour et que la réponse a été régénérée
    d2 = client.get(f"/api/v1/conversations/{conv_id}", headers=AUTH_HEADERS).json()
    assert len(d2["messages"]) == 2
    assert d2["messages"][0]["id"] == user_msg_id
    assert d2["messages"][0]["content"] == "Message modifié avec succès."
    assert d2["messages"][1]["role"] == "assistant"
    assert len(d2["messages"][1]["content"]) > 0

    # Nettoyage
    client.delete(f"/api/v1/conversations/{conv_id}", headers=AUTH_HEADERS)

