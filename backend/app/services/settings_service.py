import os
import uuid
import json
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone
from fastapi import HTTPException, status

from app.database.connection import db_manager
from app.repositories.chat_repository import ChatRepository
from app.schemas.settings_schemas import (
    UserProfileResponse,
    UserProfileUpdate,
    CloudDataDeletionResponse,
    AccountDeletionResponse,
    ShareConversationResponse,
    SharedLinkItem,
    PublicSharedConversationResponse,
    SupportFeedbackRequest,
    SupportFeedbackResponse,
    AppVersionCheckResponse,
)

logger = logging.getLogger(__name__)

OFFICIAL_SUPPORT_EMAIL = "sd.ai.founder@gmail.com"
OFFICIAL_PLAY_STORE_PACKAGE = "com.sd.chat.sd_chat_ai"
OFFICIAL_PLAY_STORE_URL = f"https://play.google.com/store/apps/details?id={OFFICIAL_PLAY_STORE_PACKAGE}"

APP_CURRENT_VERSION = "1.0.0"
APP_LATEST_VERSION = "1.0.0"
APP_MIN_SUPPORTED_VERSION = "1.0.0"


class SettingsService:
    """Service gérant le profil, le contrôle des données, les partages, le support et les versions."""

    @staticmethod
    def get_profile(user_id: str, email: Optional[str] = None) -> UserProfileResponse:
        ChatRepository.ensure_user_profile(user_id, email=email)
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                SELECT id, email, full_name, avatar_url, tier, role, preferences, created_at, updated_at
                FROM public.profiles
                WHERE id = :uid
                """,
                uid=user_id,
            )
            if not rows:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profil introuvable.")

            r = rows[0]
            prefs = r[6] if isinstance(r[6], dict) else {}
            if isinstance(r[6], str):
                try:
                    prefs = json.loads(r[6])
                except Exception:
                    prefs = {}

            return UserProfileResponse(
                id=r[0],
                email=r[1] or "",
                full_name=r[2] or "Utilisateur SD",
                avatar_url=r[3],
                tier=r[4] or "free",
                role=r[5] or "user",
                preferences=prefs,
                created_at=r[7],
                updated_at=r[8],
            )

    @staticmethod
    def update_profile(user_id: str, payload: UserProfileUpdate) -> UserProfileResponse:
        ChatRepository.ensure_user_profile(user_id)
        updates = []
        params: Dict[str, Any] = {"uid": user_id}

        if payload.full_name is not None:
            updates.append("full_name = :full_name")
            params["full_name"] = payload.full_name.strip()

        if payload.avatar_url is not None:
            updates.append("avatar_url = :avatar_url")
            params["avatar_url"] = payload.avatar_url.strip()

        if payload.preferences is not None:
            updates.append("preferences = COALESCE(preferences, CAST('{}' AS jsonb)) || CAST(:prefs AS jsonb)")
            params["prefs"] = json.dumps(payload.preferences)

        if updates:
            updates.append("updated_at = NOW()")
            set_clause = ", ".join(updates)
            with db_manager.connect() as conn:
                conn.run(
                    f"UPDATE public.profiles SET {set_clause} WHERE id = :uid",
                    **params,
                )

        return SettingsService.get_profile(user_id)

    @staticmethod
    def upload_avatar(
        user_id: str,
        content_bytes: bytes,
        filename: str,
        content_type: str,
    ) -> str:
        """Valide et enregistre la photo de profil avec isolation stricte."""
        if len(content_bytes) > 5 * 1024 * 1024:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail="L'image dépasse la taille maximale autorisée de 5 Mo.",
            )

        allowed_mimes = {"image/jpeg", "image/png", "image/webp"}
        clean_mime = content_type.lower().split(";")[0].strip()
        if clean_mime not in allowed_mimes:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Format d'image non supporté. Veuillez choisir une image JPEG, PNG ou WebP.",
            )

        # Générer un nom de fichier unique et sécurisé
        ext = "jpg" if "jpeg" in clean_mime else ("png" if "png" in clean_mime else "webp")
        avatar_filename = f"avatar_{uuid.uuid4().hex[:12]}.{ext}"
        storage_path = f"{user_id}/{avatar_filename}"

        # Sauvegarder dans la table storage.objects ou comme data URL pour résilience absolue
        try:
            from app.core.config import settings
            import base64

            # Tentative de stockage direct via base64 / Supabase storage
            b64_data = base64.b64encode(content_bytes).decode("utf-8")
            data_uri = f"data:{clean_mime};base64,{b64_data}"

            # Mettre à jour public.profiles
            with db_manager.connect() as conn:
                conn.run(
                    """
                    UPDATE public.profiles
                    SET avatar_url = :url, updated_at = NOW()
                    WHERE id = :uid
                    """,
                    uid=user_id,
                    url=data_uri,
                )

            logger.info("Avatar mis à jour pour l'utilisateur %s", user_id)
            return data_uri

        except Exception as e:
            logger.error("Erreur lors de la mise à jour de l'avatar: %s", e)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Impossible d'enregistrer la photo de profil.",
            )

    @staticmethod
    def delete_cloud_data(user_id: str) -> CloudDataDeletionResponse:
        """Supprime l'ensemble des conversations, messages et pièces jointes cloud de l'utilisateur."""
        with db_manager.connect() as conn:
            # 1. Compter les conversations existantes
            count_rows = conn.run(
                "SELECT COUNT(*) FROM public.chat_conversations WHERE user_id = :uid",
                uid=user_id,
            )
            deleted_count = int(count_rows[0][0]) if count_rows else 0

            # 2. Supprimer les messages, conversations et pièces jointes
            conn.run("DELETE FROM public.chat_messages WHERE user_id = :uid", uid=user_id)
            conn.run("DELETE FROM public.chat_attachments WHERE user_id = :uid", uid=user_id)
            conn.run("DELETE FROM public.chat_conversations WHERE user_id = :uid", uid=user_id)
            conn.run("DELETE FROM public.shared_conversations WHERE user_id = :uid", uid=user_id)

        logger.info("Données cloud supprimées pour l'utilisateur %s (%s discussions)", user_id, deleted_count)
        return CloudDataDeletionResponse(
            success=True,
            deleted_conversations_count=deleted_count,
            message="Vos discussions et messages cloud ont été supprimés avec succès.",
        )

    @staticmethod
    def delete_user_account(user_id: str) -> AccountDeletionResponse:
        """Supprime définitivement le compte utilisateur et toutes les données associées."""
        with db_manager.connect() as conn:
            # Vérifier si l'utilisateur a un abonnement actif
            sub_rows = conn.run(
                """
                SELECT plan_id, status FROM public.subscriptions
                WHERE user_id = :uid AND status = 'active'
                LIMIT 1
                """,
                uid=user_id,
            )
            if sub_rows:
                logger.warning("Suppression de compte avec abonnement actif pour %s", user_id)

            # Nettoyage en cascade complet
            conn.run("DELETE FROM public.chat_messages WHERE user_id = :uid", uid=user_id)
            conn.run("DELETE FROM public.chat_attachments WHERE user_id = :uid", uid=user_id)
            conn.run("DELETE FROM public.chat_conversations WHERE user_id = :uid", uid=user_id)
            conn.run("DELETE FROM public.shared_conversations WHERE user_id = :uid", uid=user_id)
            conn.run("DELETE FROM public.chat_user_usage WHERE user_id = :uid", uid=user_id)
            conn.run("DELETE FROM public.ai_request_metrics WHERE user_id = :uid", uid=user_id)
            conn.run("DELETE FROM public.subscriptions WHERE user_id = :uid", uid=user_id)
            conn.run("DELETE FROM public.profiles WHERE id = :uid", uid=user_id)

        # Invalidation cache
        ChatRepository._verified_profiles.discard(user_id)

        logger.info("Compte utilisateur %s supprimé définitivement.", user_id)
        return AccountDeletionResponse(
            success=True,
            message="Votre compte SD CHAT AI et toutes vos données ont été définitivement supprimés.",
        )

    @staticmethod
    def create_shared_link(user_id: str, conversation_id: str, base_url: str) -> ShareConversationResponse:
        """Génère un lien de partage public sécurisé pour une conversation."""
        conv = ChatRepository.get_conversation(conversation_id, user_id)
        if not conv:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Discussion introuvable ou accès refusé.",
            )

        share_token = f"sd_{uuid.uuid4().hex}"
        share_id = str(uuid.uuid4())
        title = conv.get("title") or "Discussion partagée"

        with db_manager.connect() as conn:
            conn.run(
                """
                INSERT INTO public.shared_conversations (
                    id, conversation_id, user_id, title, share_token, is_revoked, views_count, created_at
                ) VALUES (
                    :id, :cid, :uid, :title, :token, false, 0, NOW()
                )
                """,
                id=share_id,
                cid=conversation_id,
                uid=user_id,
                title=title,
                token=share_token,
            )

        clean_base = base_url.rstrip("/")
        share_url = f"{clean_base}/api/v1/conversations/public/{share_token}"

        return ShareConversationResponse(
            id=share_id,
            conversation_id=conversation_id,
            title=title,
            share_token=share_token,
            share_url=share_url,
            is_revoked=False,
            created_at=datetime.now(timezone.utc),
        )

    @staticmethod
    def list_shared_links(user_id: str, base_url: str) -> List[SharedLinkItem]:
        """Retourne la liste des liens partagés par l'utilisateur."""
        clean_base = base_url.rstrip("/")
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                SELECT id, conversation_id, title, share_token, is_revoked, views_count, created_at, revoked_at
                FROM public.shared_conversations
                WHERE user_id = :uid
                ORDER BY created_at DESC
                """,
                uid=user_id,
            )

            items = []
            for r in rows:
                share_token = r[3]
                items.append(
                    SharedLinkItem(
                        id=str(r[0]),
                        conversation_id=str(r[1]),
                        title=r[2] or "Discussion partagée",
                        share_token=share_token,
                        share_url=f"{clean_base}/api/v1/conversations/public/{share_token}",
                        is_revoked=bool(r[4]),
                        views_count=int(r[5] or 0),
                        created_at=r[6],
                        revoked_at=r[7],
                    )
                )
            return items

    @staticmethod
    def revoke_shared_link(user_id: str, share_id: str) -> Dict[str, Any]:
        """Révoque immédiatement un lien partagé le rendant inaccessible au public."""
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                UPDATE public.shared_conversations
                SET is_revoked = true, revoked_at = NOW()
                WHERE id = :id AND user_id = :uid
                RETURNING id
                """,
                id=share_id,
                uid=user_id,
            )
            if not rows:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Lien partagé introuvable ou vous n'avez pas l'autorisation de le modifier.",
                )

        logger.info("Lien partagé %s révoqué par l'utilisateur %s", share_id, user_id)
        return {"success": True, "share_id": share_id, "is_revoked": True, "message": "Le lien a été révoqué avec succès."}

    @staticmethod
    def get_public_shared_conversation(share_token: str) -> PublicSharedConversationResponse:
        """Affiche publiquement une discussion partagée si le lien n'est pas révoqué."""
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                SELECT sc.conversation_id, sc.title, sc.is_revoked, c.model, c.created_at
                FROM public.shared_conversations sc
                JOIN public.chat_conversations c ON c.id = sc.conversation_id
                WHERE sc.share_token = :token
                LIMIT 1
                """,
                token=share_token,
            )
            if not rows:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lien de discussion introuvable.")

            cid, title, is_revoked, model, created_at = rows[0]
            if is_revoked:
                raise HTTPException(
                    status_code=status.HTTP_410_GONE,
                    detail="Ce lien de partage a été révoqué par son auteur et n'est plus accessible.",
                )

            # Incrémenter le nombre de vues
            conn.run(
                "UPDATE public.shared_conversations SET views_count = views_count + 1 WHERE share_token = :token",
                token=share_token,
            )

            # Charger les messages publics
            msg_rows = conn.run(
                """
                SELECT role, content, created_at
                FROM public.chat_messages
                WHERE conversation_id = :cid
                ORDER BY created_at ASC
                """,
                cid=cid,
            )

            messages = [
                {
                    "role": m[0],
                    "content": m[1],
                    "created_at": m[2].isoformat() if hasattr(m[2], "isoformat") else str(m[2]),
                }
                for m in msg_rows
            ]

            return PublicSharedConversationResponse(
                title=title or "Discussion partagée",
                model=model or "SD AI Gateway",
                created_at=created_at or datetime.now(timezone.utc),
                messages=messages,
            )

    @staticmethod
    def submit_feedback(user_id: Optional[str], payload: SupportFeedbackRequest) -> SupportFeedbackResponse:
        """Enregistre un ticket de support ou commentaire utilisateur."""
        db_id = str(uuid.uuid4())
        ticket_id = db_id

        with db_manager.connect() as conn:
            conn.run(
                """
                INSERT INTO public.user_feedback (
                    id, user_id, email, category, subject, description, device_info, status, created_at
                ) VALUES (
                    :id::uuid, :uid, :email, :cat, :subj, :desc, :dev::jsonb, 'pending', NOW()
                )
                """,
                id=db_id,
                uid=user_id,
                email=str(payload.email) if payload.email else None,
                cat=payload.category,
                subj=payload.subject,
                desc=payload.description,
                dev=json.dumps(payload.device_info or {}),
            )

        logger.info(
            "Ticket de support %s créé [Catégorie: %s, Utilisateur: %s, Destinataire: %s]",
            ticket_id,
            payload.category,
            user_id,
            OFFICIAL_SUPPORT_EMAIL,
        )

        return SupportFeedbackResponse(
            ticket_id=ticket_id,
            status="received",
            message=f"Votre message a bien été transmis à l'équipe technique SD ({OFFICIAL_SUPPORT_EMAIL}). Nous vous répondrons dans les plus brefs délais.",
        )

    @staticmethod
    def check_app_version(current_version: str, platform: str = "android") -> AppVersionCheckResponse:
        """Vérifie la version installée par rapport aux versions officielles disponibles."""
        is_published = False  # Pré-release Play Store officielle en cours de revue
        is_update = False
        is_critical = False

        # Si une version supérieure existe
        if current_version != APP_LATEST_VERSION:
            is_update = True

        return AppVersionCheckResponse(
            current_version=current_version,
            latest_version=APP_LATEST_VERSION,
            min_supported_version=APP_MIN_SUPPORTED_VERSION,
            is_update_available=is_update,
            is_critical_update=is_critical,
            play_store_url=OFFICIAL_PLAY_STORE_URL,
            is_play_store_published=is_published,
            release_notes="Version 1.0.0 officielle : SD AI Gateway, multi-modèles, 4 plans SD (GNF), centre Paramètres complet et résilience réseau accrue.",
        )
