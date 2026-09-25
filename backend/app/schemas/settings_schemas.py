from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field, EmailStr


class UserProfileResponse(BaseModel):
    id: str
    email: str
    full_name: Optional[str] = "Utilisateur SD"
    avatar_url: Optional[str] = None
    tier: str = "free"
    role: str = "user"
    preferences: Dict[str, Any] = Field(default_factory=dict)
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class UserProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    preferences: Optional[Dict[str, Any]] = None


class CloudDataDeletionResponse(BaseModel):
    success: bool
    deleted_conversations_count: int
    message: str


class AccountDeletionResponse(BaseModel):
    success: bool
    message: str
    deleted_at: datetime = Field(default_factory=datetime.utcnow)


class ShareConversationResponse(BaseModel):
    id: str
    conversation_id: str
    title: str
    share_token: str
    share_url: str
    is_revoked: bool
    created_at: datetime


class SharedLinkItem(BaseModel):
    id: str
    conversation_id: str
    title: str
    share_token: str
    share_url: str
    is_revoked: bool
    views_count: int
    created_at: datetime
    revoked_at: Optional[datetime] = None


class PublicSharedConversationResponse(BaseModel):
    title: str
    model: str
    created_at: datetime
    messages: List[Dict[str, Any]]


class SupportFeedbackRequest(BaseModel):
    category: str = Field(..., description="bug, suggestion, account, payment, other")
    subject: str = Field(..., min_length=2, max_length=150)
    description: str = Field(..., min_length=5, max_length=3000)
    email: Optional[str] = None
    device_info: Optional[Dict[str, Any]] = None
    screenshot_base64: Optional[str] = None


class SupportFeedbackResponse(BaseModel):
    ticket_id: str
    status: str
    message: str
    created_at: datetime = Field(default_factory=datetime.utcnow)


class AppVersionCheckResponse(BaseModel):
    current_version: str
    latest_version: str
    min_supported_version: str
    is_update_available: bool
    is_critical_update: bool
    play_store_url: str
    is_play_store_published: bool
    release_notes: str
