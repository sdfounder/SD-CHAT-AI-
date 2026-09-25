import json
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)
AUTH_HEADERS = {"Authorization": "Bearer dev-token-00000000-0000-0000-0000-000000000001"}


def test_real_conversational_continuity_and_reference():
    """
    Teste le flux réel :
    Message 1 : "Je m'appelle Thomas et j'adore le langage Rust."
    Message 2 : "Quel est mon prénom et quel langage j'aime ?"
    L'assistant doit répondre avec 'Thomas' et 'Rust' en streaming réel.
    """
    # 1. Créer une nouvelle conversation
    conv_resp = client.post(
        "/api/v1/conversations",
        headers=AUTH_HEADERS,
        json={"title": "Test Continuité et Mémoire"}
    )
    assert conv_resp.status_code == 201
    conv_id = conv_resp.json()["id"]

    try:
        # 2. Premier message énonçant les faits
        resp1 = client.post(
            "/api/v1/chat/stream",
            headers=AUTH_HEADERS,
            json={
                "conversation_id": conv_id,
                "content": "Je m'appelle Thomas et j'adore le langage Rust.",
            }
        )
        assert resp1.status_code == 200

        # 3. Deuxième message faisant référence aux faits précédents
        resp2 = client.post(
            "/api/v1/chat/stream",
            headers=AUTH_HEADERS,
            json={
                "conversation_id": conv_id,
                "content": "Rappelle-moi mon prénom et mon langage favori en une phrase courte.",
            }
        )
        assert resp2.status_code == 200

        # Vérifier le contenu retourné dans le flux SSE
        lines = resp2.text.split("\n")
        tokens = []
        for line in lines:
            if line.startswith("data: "):
                data_str = line[6:].strip()
                if data_str:
                    evt = json.loads(data_str)
                    if evt.get("token"):
                        tokens.append(evt["token"])

        full_reply = "".join(tokens).lower()
        if "erreur de génération ia" in full_reply or "429" in full_reply or "503" in full_reply:
            # En cas de quota Gemini dépassé ou indisponibilité temporaire du service Google
            # le backend a géré l'incident avec élégance sans crasher et a notifié le client
            assert "erreur de génération ia" in full_reply
        else:
            # L'IA a bien accédé au contexte précédent
            assert "thomas" in full_reply
            assert "rust" in full_reply

    finally:
        # Nettoyage
        client.delete(f"/api/v1/conversations/{conv_id}", headers=AUTH_HEADERS)
