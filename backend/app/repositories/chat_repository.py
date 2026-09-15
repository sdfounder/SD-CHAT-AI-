import logging
from typing import List, Optional, Dict, Any
from app.database.connection import db_manager

logger = logging.getLogger(__name__)


class ChatRepository:
    """Accès aux données et persistance pour le domaine conversationnel SD CHAT AI."""

    @staticmethod
    def ensure_user_profile(user_id: str, email: Optional[str] = None, full_name: Optional[str] = None):
        """Assure que le profil utilisateur existe dans public.profiles afin de respecter les contraintes FK."""
        with db_manager.connect() as conn:
            email_val = email or f"user_{user_id[:8]}@sd-chat.ai"
            name_val = full_name or "Utilisateur SD"
            conn.run(
                """
                INSERT INTO public.profiles (id, email, full_name, role, tier, preferences, created_at, updated_at)
                VALUES (:uid, :email, :name, 'user', 'free', '{}'::jsonb, NOW(), NOW())
                ON CONFLICT (id) DO UPDATE SET
                    email = COALESCE(EXCLUDED.email, public.profiles.email),
                    updated_at = NOW()
                """,
                uid=user_id,
                email=email_val,
                name=name_val
            )

    @staticmethod
    def create_conversation(
        user_id: str,
        title: str = "Nouvelle conversation",
        model: str = "gemini-3.6-flash",
        system_prompt: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Crée une nouvelle discussion pour un utilisateur."""
        ChatRepository.ensure_user_profile(user_id)
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                INSERT INTO public.chat_conversations (user_id, title, model, system_prompt, created_at, updated_at)
                VALUES (:user_id, :title, :model, :system_prompt, NOW(), NOW())
                RETURNING id, user_id, title, model, system_prompt, is_archived, is_pinned, created_at, updated_at
                """,
                user_id=user_id,
                title=title,
                model=model,
                system_prompt=system_prompt
            )
            r = rows[0]
            return {
                "id": str(r[0]),
                "user_id": str(r[1]),
                "title": r[2],
                "model": r[3],
                "system_prompt": r[4],
                "is_archived": r[5],
                "is_pinned": r[6],
                "created_at": r[7],
                "updated_at": r[8],
                "message_count": 0,
                "last_message_preview": None
            }

    @staticmethod
    def get_user_conversations(
        user_id: str,
        include_archived: bool = False,
        limit: int = 50,
        offset: int = 0,
    ) -> List[Dict[str, Any]]:
        """Récupère l'historique des conversations d'un utilisateur avec compteurs et aperçus."""
        ChatRepository.ensure_user_profile(user_id)
        with db_manager.connect() as conn:
            archived_filter = "" if include_archived else "AND c.is_archived = FALSE"
            sql = f"""
                SELECT 
                    c.id, c.user_id, c.title, c.model, c.system_prompt, 
                    c.is_archived, c.is_pinned, c.created_at, c.updated_at,
                    COUNT(m.id) as message_count,
                    (
                        SELECT content FROM public.chat_messages lm 
                        WHERE lm.conversation_id = c.id 
                        ORDER BY lm.created_at DESC LIMIT 1
                    ) as last_message_preview
                FROM public.chat_conversations c
                LEFT JOIN public.chat_messages m ON m.conversation_id = c.id
                WHERE c.user_id = :user_id {archived_filter}
                GROUP BY c.id
                ORDER BY c.is_pinned DESC, c.updated_at DESC
                LIMIT :limit OFFSET :offset
            """
            rows = conn.run(sql, user_id=user_id, limit=limit, offset=offset)
            results = []
            for r in rows:
                results.append({
                    "id": str(r[0]),
                    "user_id": str(r[1]),
                    "title": r[2],
                    "model": r[3],
                    "system_prompt": r[4],
                    "is_archived": r[5],
                    "is_pinned": r[6],
                    "created_at": r[7],
                    "updated_at": r[8],
                    "message_count": int(r[9]),
                    "last_message_preview": r[10]
                })
            return results

    @staticmethod
    def get_conversation(conversation_id: str, user_id: str) -> Optional[Dict[str, Any]]:
        """Récupère une conversation spécifique vérifiant le propriétaire."""
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                SELECT id, user_id, title, model, system_prompt, is_archived, is_pinned, created_at, updated_at
                FROM public.chat_conversations
                WHERE id = :cid AND user_id = :uid
                """,
                cid=conversation_id,
                uid=user_id
            )
            if not rows:
                return None
            r = rows[0]
            return {
                "id": str(r[0]),
                "user_id": str(r[1]),
                "title": r[2],
                "model": r[3],
                "system_prompt": r[4],
                "is_archived": r[5],
                "is_pinned": r[6],
                "created_at": r[7],
                "updated_at": r[8]
            }

    @staticmethod
    def update_conversation(
        conversation_id: str,
        user_id: str,
        title: Optional[str] = None,
        is_archived: Optional[bool] = None,
        is_pinned: Optional[bool] = None,
    ) -> Optional[Dict[str, Any]]:
        """Met à jour les attributs d'une conversation (titre, épinglage, archivage)."""
        existing = ChatRepository.get_conversation(conversation_id, user_id)
        if not existing:
            return None

        new_title = title if title is not None else existing["title"]
        new_archived = is_archived if is_archived is not None else existing["is_archived"]
        new_pinned = is_pinned if is_pinned is not None else existing["is_pinned"]

        with db_manager.connect() as conn:
            rows = conn.run(
                """
                UPDATE public.chat_conversations
                SET title = :title, is_archived = :archived, is_pinned = :pinned, updated_at = NOW()
                WHERE id = :cid AND user_id = :uid
                RETURNING id, user_id, title, model, system_prompt, is_archived, is_pinned, created_at, updated_at
                """,
                cid=conversation_id,
                uid=user_id,
                title=new_title,
                archived=new_archived,
                pinned=new_pinned
            )
            if not rows:
                return None
            r = rows[0]
            return {
                "id": str(r[0]),
                "user_id": str(r[1]),
                "title": r[2],
                "model": r[3],
                "system_prompt": r[4],
                "is_archived": r[5],
                "is_pinned": r[6],
                "created_at": r[7],
                "updated_at": r[8]
            }

    @staticmethod
    def delete_conversation(conversation_id: str, user_id: str) -> bool:
        """Supprime définitivement une conversation et ses messages en cascade."""
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                DELETE FROM public.chat_conversations
                WHERE id = :cid AND user_id = :uid
                RETURNING id
                """,
                cid=conversation_id,
                uid=user_id
            )
            return len(rows) > 0

    @staticmethod
    def get_messages(conversation_id: str, user_id: str, limit: int = 100) -> List[Dict[str, Any]]:
        """Récupère l'historique chronologique des messages d'une conversation."""
        # Vérification préalable de propriété
        conv = ChatRepository.get_conversation(conversation_id, user_id)
        if not conv:
            return []

        with db_manager.connect() as conn:
            rows = conn.run(
                """
                SELECT id, conversation_id, user_id, role, content, tokens_used, model, created_at
                FROM public.chat_messages
                WHERE conversation_id = :cid
                ORDER BY created_at ASC
                LIMIT :limit
                """,
                cid=conversation_id,
                limit=limit
            )
            results = []
            for r in rows:
                results.append({
                    "id": str(r[0]),
                    "conversation_id": str(r[1]),
                    "user_id": str(r[2]),
                    "role": r[3],
                    "content": r[4],
                    "tokens_used": int(r[5] or 0),
                    "model": r[6],
                    "created_at": r[7]
                })
            return results

    @staticmethod
    def save_message(
        conversation_id: str,
        user_id: str,
        role: str,
        content: str,
        tokens_used: int = 0,
        model: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Enregistre un message dans la base de données."""
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                INSERT INTO public.chat_messages (conversation_id, user_id, role, content, tokens_used, model, created_at)
                VALUES (:cid, :uid, :role, :content, :tokens, :model, NOW())
                RETURNING id, conversation_id, user_id, role, content, tokens_used, model, created_at
                """,
                cid=conversation_id,
                uid=user_id,
                role=role,
                content=content,
                tokens=tokens_used,
                model=model
            )
            r = rows[0]
            return {
                "id": str(r[0]),
                "conversation_id": str(r[1]),
                "user_id": str(r[2]),
                "role": r[3],
                "content": r[4],
                "tokens_used": int(r[5] or 0),
                "model": r[6],
                "created_at": r[7]
            }
