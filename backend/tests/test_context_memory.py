import asyncio
import pytest
from app.repositories.chat_repository import ChatRepository
from app.services.context_service import ContextService, MAX_RECENT_MESSAGES_WINDOW
from app.ai.base_provider import BaseLLMProvider


class MockTestLLMProvider(BaseLLMProvider):
    """Provider IA léger pour les tests unitaires de contexte et résumé."""

    @property
    def provider_name(self) -> str:
        return "mock_test_llm"

    @property
    def model_name(self) -> str:
        return "mock-test-model"

    async def generate_stream(self, messages, system_instruction=None, temperature=0.7, max_tokens=4096):
        yield "Réponse"
        yield " de test"

    async def generate(self, messages, system_instruction=None, temperature=0.7, max_tokens=4096):
        return "L'utilisateur et l'assistant ont discuté du développement de SD CHAT AI et des objectifs d'architecture."


def test_short_conversation_context_verbatim():
    async def _run():
        user_id = "test-user-context-001"
        provider = MockTestLLMProvider()

        # 1. Création d'une conversation
        conv = ChatRepository.create_conversation(user_id=user_id, title="Discussion courte")
        conv_id = conv["id"]

        # 2. Ajout de 3 messages
        ChatRepository.save_message(conv_id, user_id, "user", "Bonjour, je m'appelle Alice.")
        ChatRepository.save_message(conv_id, user_id, "assistant", "Enchanté Alice ! Comment puis-je t'aider ?")
        ChatRepository.save_message(conv_id, user_id, "user", "Rappelle-toi de mon prénom.")

        # 3. Préparation du contexte
        context = await ContextService.prepare_context_messages(conv_id, user_id, provider)

        # Doit contenir exactement les 3 messages sans altération ni résumé (conversation courte <= 10)
        assert len(context) == 3
        assert context[0]["role"] == "user"
        assert "Alice" in context[0]["content"]
        assert context[1]["role"] == "assistant"
        assert context[2]["role"] == "user"
        assert "prénom" in context[2]["content"]

        # Nettoyage
        ChatRepository.delete_conversation(conv_id, user_id)

    asyncio.run(_run())


def test_context_strict_user_and_conversation_isolation():
    async def _run():
        user_a = "user-alice-0001"
        user_b = "user-bob-0002"
        provider = MockTestLLMProvider()

        conv_a = ChatRepository.create_conversation(user_id=user_a, title="Secret Alice")
        ChatRepository.save_message(conv_a["id"], user_a, "user", "Mon code secret est 9876.")

        # Tentative d'accès de Bob à la conversation d'Alice
        context_b = await ContextService.prepare_context_messages(conv_a["id"], user_b, provider)
        # L'accès doit être strictement vide (isolation totale)
        assert context_b == []

        # Nettoyage
        ChatRepository.delete_conversation(conv_a["id"], user_a)

    asyncio.run(_run())


def test_attachment_metadata_inclusion_in_context():
    async def _run():
        user_id = "test-user-att-ctx-001"
        provider = MockTestLLMProvider()

        conv = ChatRepository.create_conversation(user_id=user_id, title="Test pièce jointe contexte")
        conv_id = conv["id"]

        msg = ChatRepository.save_message(conv_id, user_id, "user", "Analyse ce document pour moi.")
        msg_id = msg["id"]

        # Création et liaison d'une pièce jointe
        att = ChatRepository.create_attachment(
            attachment_id="00000000-0000-0000-0000-000000000999",
            user_id=user_id,
            file_name="bilan_q3.txt",
            file_type="text",
            storage_path="path/bilan_q3.txt",
            mime_type="text/plain",
            file_size_bytes=2048,
            conversation_id=conv_id,
            content_bytes=b"Contenu du bilan",
        )
        ChatRepository.link_attachments_to_message([att["id"]], msg_id, conv_id, user_id)

        # Récupérer le contexte
        context = await ContextService.prepare_context_messages(conv_id, user_id, provider)

        assert len(context) == 1
        # Vérifier la présence des métadonnées injectées
        assert "bilan_q3.txt" in context[0]["content"]
        assert "text" in context[0]["content"]
        assert "2 Ko" in context[0]["content"]

        # Nettoyage
        ChatRepository.delete_attachment(att["id"], user_id)
        ChatRepository.delete_conversation(conv_id, user_id)

    asyncio.run(_run())


def test_long_conversation_rolling_summarization():
    async def _run():
        user_id = "test-user-long-conv-001"
        provider = MockTestLLMProvider()

        conv = ChatRepository.create_conversation(user_id=user_id, title="Longue discussion")
        conv_id = conv["id"]

        # Insérer 16 messages (8 tours)
        for i in range(1, 17):
            role = "user" if i % 2 != 0 else "assistant"
            content = f"Message numéro {i} abordant le sujet technique {i}."
            ChatRepository.save_message(conv_id, user_id, role, content)

        # Vérifier que le contexte compresse les anciens messages et garde les récents
        context = await ContextService.prepare_context_messages(conv_id, user_id, provider)

        # Le premier message doit contenir le résumé mémoriel
        assert any("[Mémoire de contexte de cette conversation" in m["content"] for m in context)

        # Les 10 derniers messages récents doivent être présents verbatim
        assert len(context) >= MAX_RECENT_MESSAGES_WINDOW

        # Vérifier la persistance dans Supabase de context_summary
        updated_conv = ChatRepository.get_conversation(conv_id, user_id)
        assert updated_conv["context_summary"] is not None
        assert len(updated_conv["context_summary"]) > 0
        assert updated_conv["summary_until_message_id"] is not None

        # Nettoyage
        ChatRepository.delete_conversation(conv_id, user_id)

    asyncio.run(_run())


def test_user_memory_future_readiness_flag():
    # L'architecture de mémoire utilisateur est prête mais désactivée par défaut
    memories = ContextService.get_user_memories("any-user")
    assert memories == []

