import logging
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse

from app.core.security import get_current_user, AuthenticatedUser
from app.schemas.chat_schemas import SendMessageRequest
from app.services.chat_service import ChatService

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
    Reçoit le message de l'utilisateur, déclenche l'IA (Gemini V1) et renvoie
    les morceaux de texte en flux continu (Server-Sent Events).
    """
    return StreamingResponse(
        ChatService.stream_chat(current_user, request),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        }
    )
