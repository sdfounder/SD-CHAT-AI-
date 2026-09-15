from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query

from app.core.security import get_current_user, AuthenticatedUser
from app.schemas.chat_schemas import (
    ConversationResponse,
    ConversationDetailResponse,
    ConversationCreate,
    ConversationUpdate,
    MessageResponse,
)
from app.repositories.chat_repository import ChatRepository

router = APIRouter(prefix="/conversations", tags=["Conversations"])


@router.get("", response_model=List[ConversationResponse], summary="Lister les conversations de l'utilisateur")
async def list_conversations(
    include_archived: bool = Query(default=False),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    conversations = ChatRepository.get_user_conversations(
        user_id=current_user.id,
        include_archived=include_archived,
        limit=limit,
        offset=offset
    )
    return [ConversationResponse(**c) for c in conversations]


@router.post("", response_model=ConversationResponse, status_code=status.HTTP_201_CREATED, summary="Créer une nouvelle conversation")
async def create_conversation(
    payload: ConversationCreate,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    created = ChatRepository.create_conversation(
        user_id=current_user.id,
        title=payload.title or "Nouvelle conversation",
        model=payload.model or "gemini-3.6-flash",
        system_prompt=payload.system_prompt
    )
    return ConversationResponse(**created)


@router.get("/{conversation_id}", response_model=ConversationDetailResponse, summary="Obtenir les détails et messages d'une discussion")
async def get_conversation_detail(
    conversation_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    conv = ChatRepository.get_conversation(conversation_id, current_user.id)
    if not conv:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation introuvable ou accès refusé",
        )
    messages = ChatRepository.get_messages(conversation_id, current_user.id)
    return ConversationDetailResponse(
        conversation=ConversationResponse(**conv),
        messages=[MessageResponse(**m) for m in messages]
    )


@router.patch("/{conversation_id}", response_model=ConversationResponse, summary="Renommer, épingler ou archiver une discussion")
async def update_conversation(
    conversation_id: str,
    payload: ConversationUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    updated = ChatRepository.update_conversation(
        conversation_id=conversation_id,
        user_id=current_user.id,
        title=payload.title,
        is_archived=payload.is_archived,
        is_pinned=payload.is_pinned,
    )
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation introuvable ou mise à jour échouée",
        )
    return ConversationResponse(**updated)


@router.delete("/{conversation_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Supprimer une conversation")
async def delete_conversation(
    conversation_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    success = ChatRepository.delete_conversation(conversation_id, current_user.id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation introuvable ou déjà supprimée",
        )
    return None
