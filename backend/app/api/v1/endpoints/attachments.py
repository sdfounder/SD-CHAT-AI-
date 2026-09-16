import uuid
import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Response

from app.core.security import get_current_user, AuthenticatedUser
from app.schemas.chat_schemas import AttachmentResponse
from app.repositories.chat_repository import ChatRepository
from app.services.quota_service import QuotaService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/attachments", tags=["Attachments"])

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 Mo

ALLOWED_IMAGE_MIMES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
}

ALLOWED_TEXT_MIMES = {
    "text/plain",
    "text/markdown",
    "text/csv",
    "application/x-empty",
}

ALLOWED_TEXT_EXTENSIONS = {
    ".txt",
    ".md",
    ".csv",
    ".log",
}

ALLOWED_IMAGE_EXTENSIONS = {
    ".jpg",
    ".jpeg",
    ".png",
    ".webp",
    ".gif",
}


def _determine_file_type(filename: str, content_type: Optional[str]) -> str:
    """Détermine si le fichier est une image ou un texte autorisé, sinon lève une exception."""
    lower_name = filename.lower() if filename else ""
    mime = (content_type or "").lower().split(";")[0].strip()

    # Vérification image
    if mime in ALLOWED_IMAGE_MIMES or any(lower_name.endswith(ext) for ext in ALLOWED_IMAGE_EXTENSIONS):
        return "image"

    # Vérification texte
    if mime in ALLOWED_TEXT_MIMES or any(lower_name.endswith(ext) for ext in ALLOWED_TEXT_EXTENSIONS):
        return "text"

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Format de fichier non pris en charge. Formats acceptés : Images (JPEG, PNG, WebP, GIF) et Fichiers texte (.txt, .md, .csv).",
    )


@router.post("/upload", response_model=AttachmentResponse, status_code=status.HTTP_201_CREATED, summary="Téléverser une pièce jointe (Image ou Fichier texte)")
async def upload_attachment(
    file: UploadFile = File(...),
    conversation_id: Optional[str] = Form(None),
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Téléverse et stocke de façon sécurisée une image ou un fichier TXT/MD/CSV.
    Contrôle strict de la taille (< 10 Mo) et du type MIME.
    """
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Nom de fichier invalide.",
        )

    file_type = _determine_file_type(file.filename, file.content_type)

    # Lecture sécurisée du contenu avec contrôle de taille
    content_bytes = await file.read()
    file_size = len(content_bytes)

    if file_size == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le fichier sélectionné est vide.",
        )

    if file_size > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Le fichier dépasse la taille maximale autorisée de 10 Mo.",
        )

    # Contrôle strict du quota journalier de pièces jointes (Free: 3/j, Premium: 50/j)
    QuotaService.check_and_consume_attachment_quota(current_user.id)

    attachment_id = str(uuid.uuid4())
    safe_filename = file.filename.replace("/", "_").replace("\\", "_")
    storage_path = f"{current_user.id}/{attachment_id}/{safe_filename}"
    mime_type = file.content_type or ("image/jpeg" if file_type == "image" else "text/plain")

    # Persistance métadonnées + données binaires dans Supabase PostgreSQL
    try:
        created = ChatRepository.create_attachment(
            attachment_id=attachment_id,
            user_id=current_user.id,
            file_name=safe_filename,
            file_type=file_type,
            storage_path=storage_path,
            mime_type=mime_type,
            file_size_bytes=file_size,
            conversation_id=conversation_id,
            content_bytes=content_bytes,
        )
        return AttachmentResponse(**created)
    except Exception as e:
        logger.error("Erreur lors de l'enregistrement de la pièce jointe: %s", str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Impossible d'enregistrer la pièce jointe.",
        )


@router.get("/{attachment_id}", response_model=AttachmentResponse, summary="Obtenir les métadonnées d'une pièce jointe")
async def get_attachment_metadata(
    attachment_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """Récupère les métadonnées d'une pièce jointe appartenant à l'utilisateur connecté."""
    att = ChatRepository.get_attachment(attachment_id, current_user.id)
    if not att:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pièce jointe introuvable ou accès non autorisé.",
        )
    return AttachmentResponse(**att)


@router.get("/{attachment_id}/raw", summary="Télécharger ou afficher le contenu binaire d'une pièce jointe")
async def get_attachment_raw(
    attachment_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """Sert le contenu binaire réel du fichier de façon sécurisée (avec vérification de propriété)."""
    blob_data = ChatRepository.get_attachment_blob(attachment_id, current_user.id)
    if not blob_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fichier introuvable ou accès non autorisé.",
        )

    headers = {
        "Content-Disposition": f'inline; filename="{blob_data["file_name"]}"',
        "Content-Length": str(blob_data["file_size_bytes"]),
    }
    return Response(
        content=blob_data["content_bytes"],
        media_type=blob_data["mime_type"],
        headers=headers,
    )


@router.delete("/{attachment_id}", summary="Supprimer une pièce jointe")
async def delete_attachment(
    attachment_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """Supprime définitivement une pièce jointe et ses données binaires."""
    deleted = ChatRepository.delete_attachment(attachment_id, current_user.id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pièce jointe introuvable ou déjà supprimée.",
        )
    return {"success": True, "message": "Pièce jointe supprimée avec succès."}
