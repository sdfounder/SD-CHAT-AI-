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
        """Récupère l'historique chronologique des messages d'une conversation avec leurs pièces jointes."""
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
            if not rows:
                return []

            # Récupérer les pièces jointes associées à ces messages
            att_rows = conn.run(
                """
                SELECT id, conversation_id, message_id, user_id, file_name, file_type, storage_path, mime_type, file_size_bytes, created_at
                FROM public.chat_attachments
                WHERE conversation_id = :cid AND message_id IS NOT NULL
                ORDER BY created_at ASC
                """,
                cid=conversation_id
            )
            attachments_by_msg: Dict[str, List[Dict[str, Any]]] = {}
            for ar in att_rows:
                mid = str(ar[2])
                att_item = {
                    "id": str(ar[0]),
                    "conversation_id": str(ar[1]) if ar[1] else None,
                    "message_id": mid,
                    "user_id": str(ar[3]),
                    "file_name": ar[4],
                    "file_type": ar[5],
                    "storage_path": ar[6],
                    "mime_type": ar[7],
                    "file_size_bytes": int(ar[8]),
                    "created_at": ar[9],
                    "url": f"/api/v1/attachments/{str(ar[0])}"
                }
                attachments_by_msg.setdefault(mid, []).append(att_item)

            results = []
            for r in rows:
                msg_id = str(r[0])
                results.append({
                    "id": msg_id,
                    "conversation_id": str(r[1]),
                    "user_id": str(r[2]),
                    "role": r[3],
                    "content": r[4],
                    "tokens_used": int(r[5] or 0),
                    "model": r[6],
                    "created_at": r[7],
                    "attachments": attachments_by_msg.get(msg_id, [])
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

    @staticmethod
    def edit_and_truncate_after(
        conversation_id: str,
        message_id: str,
        user_id: str,
        new_content: str,
    ) -> Optional[Dict[str, Any]]:
        """Modifie le message utilisateur et supprime tous les messages postérieurs pour régénérer la conversation."""
        with db_manager.connect() as conn:
            # 1. Vérifier le message et récupérer sa date
            target = conn.run(
                """
                SELECT id, created_at, role
                FROM public.chat_messages
                WHERE id = :mid AND conversation_id = :cid AND user_id = :uid
                """,
                mid=message_id,
                cid=conversation_id,
                uid=user_id
            )
            if not target:
                return None

            created_at = target[0][1]

            # 2. Supprimer tous les messages strictement postérieurs dans cette discussion
            conn.run(
                """
                DELETE FROM public.chat_messages
                WHERE conversation_id = :cid AND created_at > :created_at
                """,
                cid=conversation_id,
                created_at=created_at
            )

            # 3. Mettre à jour le message cible avec le nouveau contenu
            tokens = len(new_content.split())
            rows = conn.run(
                """
                UPDATE public.chat_messages
                SET content = :content, tokens_used = :tokens
                WHERE id = :mid
                RETURNING id, conversation_id, user_id, role, content, tokens_used, model, created_at
                """,
                content=new_content,
                tokens=tokens,
                mid=message_id
            )
            if not rows:
                return None
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

    @staticmethod
    def create_attachment(
        attachment_id: str,
        user_id: str,
        file_name: str,
        file_type: str,
        storage_path: str,
        mime_type: str,
        file_size_bytes: int,
        conversation_id: Optional[str] = None,
        content_bytes: Optional[bytes] = None,
    ) -> Dict[str, Any]:
        """Enregistre les métadonnées et le contenu binaire d'une pièce jointe."""
        ChatRepository.ensure_user_profile(user_id)
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                INSERT INTO public.chat_attachments 
                (id, user_id, conversation_id, file_name, file_type, storage_path, mime_type, file_size_bytes, created_at)
                VALUES (:aid, :uid, :cid, :fname, :ftype, :spath, :mime, :fsize, NOW())
                RETURNING id, conversation_id, message_id, user_id, file_name, file_type, storage_path, mime_type, file_size_bytes, created_at
                """,
                aid=attachment_id,
                uid=user_id,
                cid=conversation_id,
                fname=file_name,
                ftype=file_type,
                spath=storage_path,
                mime=mime_type,
                fsize=file_size_bytes,
            )
            r = rows[0]

            if content_bytes is not None:
                conn.run(
                    """
                    INSERT INTO public.chat_attachment_blobs (attachment_id, content_bytes, created_at)
                    VALUES (:aid, :content, NOW())
                    ON CONFLICT (attachment_id) DO UPDATE SET content_bytes = EXCLUDED.content_bytes
                    """,
                    aid=attachment_id,
                    content=content_bytes,
                )

            return {
                "id": str(r[0]),
                "conversation_id": str(r[1]) if r[1] else None,
                "message_id": str(r[2]) if r[2] else None,
                "user_id": str(r[3]),
                "file_name": r[4],
                "file_type": r[5],
                "storage_path": r[6],
                "mime_type": r[7],
                "file_size_bytes": int(r[8]),
                "created_at": r[9],
                "url": f"/api/v1/attachments/{str(r[0])}",
            }

    @staticmethod
    def get_attachment(attachment_id: str, user_id: str) -> Optional[Dict[str, Any]]:
        """Récupère les métadonnées d'une pièce jointe en vérifiant le propriétaire."""
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                SELECT id, conversation_id, message_id, user_id, file_name, file_type, storage_path, mime_type, file_size_bytes, created_at
                FROM public.chat_attachments
                WHERE id = :aid AND user_id = :uid
                """,
                aid=attachment_id,
                uid=user_id,
            )
            if not rows:
                return None
            r = rows[0]
            return {
                "id": str(r[0]),
                "conversation_id": str(r[1]) if r[1] else None,
                "message_id": str(r[2]) if r[2] else None,
                "user_id": str(r[3]),
                "file_name": r[4],
                "file_type": r[5],
                "storage_path": r[6],
                "mime_type": r[7],
                "file_size_bytes": int(r[8]),
                "created_at": r[9],
                "url": f"/api/v1/attachments/{str(r[0])}",
            }

    @staticmethod
    def get_attachment_blob(attachment_id: str, user_id: str) -> Optional[Dict[str, Any]]:
        """Récupère le contenu binaire et le type MIME d'une pièce jointe avec vérification de sécurité."""
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                SELECT a.id, a.file_name, a.mime_type, a.file_size_bytes, b.content_bytes
                FROM public.chat_attachments a
                JOIN public.chat_attachment_blobs b ON b.attachment_id = a.id
                WHERE a.id = :aid AND a.user_id = :uid
                """,
                aid=attachment_id,
                uid=user_id,
            )
            if not rows:
                return None
            r = rows[0]
            content = r[4]
            if isinstance(content, memoryview):
                content = content.tobytes()
            return {
                "id": str(r[0]),
                "file_name": r[1],
                "mime_type": r[2],
                "file_size_bytes": int(r[3]),
                "content_bytes": content,
            }

    @staticmethod
    def link_attachments_to_message(
        attachment_ids: List[str],
        message_id: str,
        conversation_id: str,
        user_id: str,
    ) -> None:
        """Rattache une liste de pièces jointes à un message et une conversation."""
        if not attachment_ids:
            return
        with db_manager.connect() as conn:
            for aid in attachment_ids:
                conn.run(
                    """
                    UPDATE public.chat_attachments
                    SET message_id = :mid, conversation_id = :cid
                    WHERE id = :aid AND user_id = :uid
                    """,
                    mid=message_id,
                    cid=conversation_id,
                    aid=aid,
                    uid=user_id,
                )

    @staticmethod
    def delete_attachment(attachment_id: str, user_id: str) -> bool:
        """Supprime une pièce jointe et son contenu binaire (cascade)."""
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                DELETE FROM public.chat_attachments
                WHERE id = :aid AND user_id = :uid
                RETURNING id
                """,
                aid=attachment_id,
                uid=user_id,
            )
            return len(rows) > 0

