import logging
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse

from app.core.security import get_current_user, AuthenticatedUser
from app.schemas.chat_schemas import SendMessageRequest
from app.services.chat_service import ChatService
from app.services.quota_service import QuotaService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/chat", tags=["Chat"])


@router.post(
    "/stream",
    summary="Envoyer un message et recevoir la réponse en streaming SSE",
    response_description="Flux SSE contenant les tokens temps réel"
)
async def stream_chat_message(
    request: SendMessageRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Point d'entrée principal pour la discussion IA :
    1. Vérifie et décompte le quota du plan (Free: 20/j, Premium: 500/j).
       Si le quota est atteint, lève immédiatement HTTP 429 Too Many Requests.
    2. Reçoit le message de l'utilisateur, déclenche l'IA (Gemini V1) et renvoie
       les morceaux de texte en flux continu (Server-Sent Events).
    """
    # Contrôle du quota : nouveau message = consommation, régénération/édition = pas de double décompte
    if not request.edit_message_id:
        QuotaService.check_and_consume_message_quota(current_user.id)
    else:
        status_info = QuotaService.get_quota_status(current_user.id)
        if status_info.is_quota_exceeded:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "error_code": "QUOTA_EXCEEDED",
                    "message": "Quota journalier atteint.",
                    "plan": status_info.plan,
                    "reset_at": status_info.reset_at.isoformat(),
                }
            )

    return StreamingResponse(
        ChatService.stream_chat(current_user, request),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        }
    )

