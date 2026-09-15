import json
import logging
from typing import AsyncGenerator, Dict, Any, Optional, List
from fastapi import HTTPException, status

from app.core.security import AuthenticatedUser
from app.schemas.chat_schemas import SendMessageRequest
from app.repositories.chat_repository import ChatRepository
from app.ai import get_ai_provider

logger = logging.getLogger(__name__)


class ChatService:
    """Service d'orchestration conversationnelle et streaming IA."""

    @staticmethod
    def _generate_title(content: str) -> str:
        """Génère un titre concis et lisible à partir du premier message utilisateur."""
        cleaned = content.strip().replace("\n", " ")
        words = cleaned.split()
        if len(words) <= 6:
            return cleaned[:45]
        return " ".join(words[:5]) + "..."

    @staticmethod
    async def stream_chat(
        user: AuthenticatedUser,
        request: SendMessageRequest,
    ) -> AsyncGenerator[str, None]:
        """
        Orchestre le flux complet de message :
        1. Résolution ou création de la conversation.
        2. Persistance du message utilisateur.
        3. Récupération de l'historique contextuel.
        4. Invocation de l'IA (Gemini V1) en streaming.
        5. Émission des tokens en Server-Sent Events (SSE).
        6. Persistance du message de réponse assistant et finalisation.
        """
        user_id = user.id

        # 1. Résolution ou création de conversation
        is_new_conversation = False
        conversation_id = request.conversation_id

        if not conversation_id:
            # Créer une nouvelle conversation
            title = ChatService._generate_title(request.content)
            conv = ChatRepository.create_conversation(
                user_id=user_id,
                title=title,
                model=request.model or "gemini-3.6-flash",
                system_prompt=request.system_prompt
            )
            conversation_id = conv["id"]
            is_new_conversation = True
        else:
            conv = ChatRepository.get_conversation(conversation_id, user_id)
            if not conv:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Conversation introuvable ou non autorisée",
                )

        # 2. Sauvegarde du message utilisateur
        ChatRepository.save_message(
            conversation_id=conversation_id,
            user_id=user_id,
            role="user",
            content=request.content,
            tokens_used=len(request.content.split()),
            model=request.model
        )

        # Émettre le premier événement pour informer le client de l'ID conversation
        init_event = {
            "token": "",
            "done": False,
            "conversation_id": conversation_id,
            "title": conv.get("title") or "Nouvelle conversation"
        }
        yield f"data: {json.dumps(init_event, ensure_ascii=False)}\n\n"

        # 3. Récupération de l'historique (derniers 20 messages pour le contexte)
        past_messages = ChatRepository.get_messages(conversation_id, user_id, limit=20)
        formatted_history: List[Dict[str, str]] = []
        for m in past_messages:
            formatted_history.append({
                "role": m["role"],
                "content": m["content"]
            })

        # 4. Instanciation du Provider IA
        ai_provider = get_ai_provider("gemini", model=request.model)

        system_instruction = request.system_prompt or conv.get("system_prompt") or (
            "Tu es SD CHAT AI, un assistant d'intelligence artificielle hautement performant, "
            "élégant, précis et bienveillant, créé au sein de l'écosystème SD fondé par Sekou Diaby. "
            "Réponds avec clarté, pertinence et une excellente mise en forme Markdown lorsque pertinent."
        )

        accumulated_response: List[str] = []

        try:
            async for token in ai_provider.generate_stream(
                messages=formatted_history,
                system_instruction=system_instruction,
                temperature=request.temperature or 0.7,
            ):
                accumulated_response.append(token)
                event = {
                    "token": token,
                    "done": False,
                    "conversation_id": conversation_id
                }
                yield f"data: {json.dumps(event, ensure_ascii=False)}\n\n"

        except Exception as e:
            logger.error("Erreur lors du streaming IA: %s", str(e))
            error_event = {
                "token": f"\n\n*[Erreur de génération IA: {str(e)}]*",
                "done": False,
                "conversation_id": conversation_id,
                "error": True
            }
            yield f"data: {json.dumps(error_event, ensure_ascii=False)}\n\n"
            accumulated_response.append(f"\n\n*[Erreur de génération IA: {str(e)}]*")

        # 5. Persistance du message assistant
        full_content = "".join(accumulated_response)
        tokens_count = len(full_content.split())

        assistant_msg = ChatRepository.save_message(
            conversation_id=conversation_id,
            user_id=user_id,
            role="assistant",
            content=full_content,
            tokens_used=tokens_count,
            model=ai_provider.model_name
        )

        # Mise à jour éventuelle du titre si c'était une nouvelle conversation
        final_title = conv.get("title")
        if is_new_conversation and (not final_title or final_title == "Nouvelle conversation"):
            final_title = ChatService._generate_title(request.content)
            ChatRepository.update_conversation(conversation_id, user_id, title=final_title)

        # 6. Événement final signalant la fin du streaming
        final_event = {
            "token": "",
            "done": True,
            "conversation_id": conversation_id,
            "message_id": assistant_msg["id"],
            "title": final_title
        }
        yield f"data: {json.dumps(final_event, ensure_ascii=False)}\n\n"
