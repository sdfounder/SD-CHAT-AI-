from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field


class ConversationCreate(BaseModel):
    title: Optional[str] = Field(default="Nouvelle conversation", description="Titre de la discussion")
    model: Optional[str] = Field(default="gemini-3.6-flash", description="Modèle IA sélectionné")
    system_prompt: Optional[str] = Field(default=None, description="Consigne système optionnelle")


class ConversationUpdate(BaseModel):
    title: Optional[str] = Field(default=None)
    is_archived: Optional[bool] = Field(default=None)
    is_pinned: Optional[bool] = Field(default=None)


class ConversationResponse(BaseModel):
    id: str
    user_id: str
    title: str
    model: str
    system_prompt: Optional[str] = None
    is_archived: bool = False
    is_pinned: bool = False
    created_at: datetime
    updated_at: datetime
    message_count: Optional[int] = 0
    last_message_preview: Optional[str] = None


class MessageResponse(BaseModel):
    id: str
    conversation_id: str
    user_id: str
    role: str  # 'user', 'assistant', 'system'
    content: str
    tokens_used: int = 0
    model: Optional[str] = None
    created_at: datetime


class ConversationDetailResponse(BaseModel):
    conversation: ConversationResponse
    messages: List[MessageResponse]


class SendMessageRequest(BaseModel):
    conversation_id: Optional[str] = Field(
        default=None,
        description="ID de la conversation existante. Si absent, une nouvelle conversation est créée automatiquement."
    )
    content: str = Field(..., min_length=1, description="Message textuel envoyé par l'utilisateur")
    model: Optional[str] = Field(default="gemini-3.6-flash", description="Modèle IA cible")
    system_prompt: Optional[str] = Field(default=None, description="Consigne de rôle ou personnalisation")
    temperature: Optional[float] = Field(default=0.7, ge=0.0, le=1.0)
    edit_message_id: Optional[str] = Field(
        default=None,
        description="ID du message utilisateur à modifier pour régénérer la réponse à partir de ce point."
    )


class StreamTokenChunk(BaseModel):
    token: str
    done: bool = False
    conversation_id: Optional[str] = None
    message_id: Optional[str] = None
    title: Optional[str] = None
