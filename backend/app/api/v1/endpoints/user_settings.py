from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Query, Request

from app.core.security import get_current_user, get_current_user_optional, AuthenticatedUser
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
from app.services.settings_service import SettingsService

router = APIRouter(tags=["User Settings & Data Control"])


# ====================================================================
# PROFIL UTILISATEUR
# ====================================================================

@router.get("/profile", response_model=UserProfileResponse, summary="Obtenir le profil complet de l'utilisateur connecté")
async def get_user_profile(current_user: AuthenticatedUser = Depends(get_current_user)):
    return SettingsService.get_profile(current_user.id, email=current_user.email)


@router.patch("/profile", response_model=UserProfileResponse, summary="Mettre à jour le profil (nom, avatar, préférences)")
async def update_user_profile(
    payload: UserProfileUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    return SettingsService.update_profile(current_user.id, payload)


@router.post("/profile/avatar", summary="Téléverser et mettre à jour la photo de profil")
async def upload_user_avatar(
    file: UploadFile = File(...),
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    if not file.filename:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Nom de fichier invalide.")

    content = await file.read()
    avatar_url = SettingsService.upload_avatar(
        user_id=current_user.id,
        content_bytes=content,
        filename=file.filename,
        content_type=file.content_type or "image/jpeg",
    )
    return {"avatar_url": avatar_url, "success": True}


# ====================================================================
# CONTRÔLE DES DONNÉES & SUPPRESSION
# ====================================================================

@router.delete("/data/cloud", response_model=CloudDataDeletionResponse, summary="Supprimer l'ensemble des discussions et messages cloud")
async def delete_user_cloud_data(current_user: AuthenticatedUser = Depends(get_current_user)):
    return SettingsService.delete_cloud_data(current_user.id)


@router.delete("/users/me", response_model=AccountDeletionResponse, summary="Supprimer définitivement le compte utilisateur et ses données")
async def delete_user_account(current_user: AuthenticatedUser = Depends(get_current_user)):
    return SettingsService.delete_user_account(current_user.id)


# ====================================================================
# LIENS PARTAGÉS
# ====================================================================

@router.post(
    "/conversations/{conversation_id}/share",
    response_model=ShareConversationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Créer un lien de partage public pour une conversation",
)
async def create_conversation_share(
    conversation_id: str,
    request: Request,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    base_url = str(request.base_url)
    return SettingsService.create_shared_link(current_user.id, conversation_id, base_url)


@router.get(
    "/conversations/shared/links",
    response_model=List[SharedLinkItem],
    summary="Lister les liens partagés créés par l'utilisateur",
)
async def list_user_shared_links(
    request: Request,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    base_url = str(request.base_url)
    return SettingsService.list_shared_links(current_user.id, base_url)


@router.delete(
    "/conversations/shared/{share_id}",
    summary="Révoquer un lien de partage public",
)
async def revoke_shared_link(
    share_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    return SettingsService.revoke_shared_link(current_user.id, share_id)


@router.get(
    "/conversations/public/{share_token}",
    response_model=PublicSharedConversationResponse,
    summary="Consulter publiquement une conversation partagée (si non révoquée)",
)
async def get_public_shared_conversation(share_token: str):
    return SettingsService.get_public_shared_conversation(share_token)


# ====================================================================
# AIDE & COMMENTAIRES / SUPPORT
# ====================================================================

@router.post(
    "/support/feedback",
    response_model=SupportFeedbackResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Envoyer un signalement de bug ou un commentaire à l'équipe technique",
)
async def submit_support_feedback(
    payload: SupportFeedbackRequest,
    current_user: Optional[AuthenticatedUser] = Depends(get_current_user_optional),
):
    user_id = current_user.id if current_user else None
    return SettingsService.submit_feedback(user_id, payload)


# ====================================================================
# VÉRIFICATION DES MISES À JOUR
# ====================================================================

@router.get(
    "/app/version-check",
    response_model=AppVersionCheckResponse,
    summary="Vérifier la version de l'application par rapport à Google Play",
)
async def check_app_version(
    current_version: str = Query("1.0.0"),
    platform: str = Query("android"),
):
    return SettingsService.check_app_version(current_version, platform)


# ====================================================================
# PULSATION DE PRÉSENCE / HEARTBEAT
# ====================================================================

@router.post(
    "/users/heartbeat",
    summary="Pulsation de présence de l'utilisateur pour le statut en ligne",
)
async def user_heartbeat(current_user: AuthenticatedUser = Depends(get_current_user)):
    from app.database.connection import db_manager
    from datetime import datetime, timezone
    with db_manager.connect() as conn:
        conn.run("UPDATE public.profiles SET last_active_at = NOW() WHERE id = :uid", uid=current_user.id)
    return {"status": "ok", "user_id": current_user.id, "timestamp": datetime.now(timezone.utc).isoformat()}

