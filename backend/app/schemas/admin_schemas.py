from datetime import datetime
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class AdminLoginRequest(BaseModel):
    email: str
    password: str


class AdminGoogleLoginRequest(BaseModel):
    access_token: Optional[str] = None
    id_token: Optional[str] = None
    email: Optional[str] = None
    full_name: Optional[str] = None
    user_id: Optional[str] = None


class AdminRegisterRequest(BaseModel):
    email: str
    password: str
    full_name: Optional[str] = "Administrateur SD"
    supabase_token: Optional[str] = None
    user_id: Optional[str] = None


class AdminStatusResponse(BaseModel):
    has_admin: bool
    registration_open: bool
    admin_email_masked: Optional[str] = None
    admin_name: Optional[str] = None


class AdminLoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    admin: Dict[str, Any]


class AdminStatsResponse(BaseModel):
    total_users: int
    active_users_24h: int
    active_users_7d: int
    online_users_count: int = 0
    total_conversations: int
    total_messages: int
    total_attachments: int
    free_users_count: int
    premium_users_count: int
    vip_users_count: int = 0
    black_users_count: int = 0
    suspended_users_count: int
    blocked_users_count: int = 0
    pending_feedback_count: int = 0
    unread_alerts_count: int = 0
    total_tokens_estimated: int
    total_gemini_requests_today: int
    stripe_active_subscriptions: int
    stripe_mrr_eur: float


class AdminUserItem(BaseModel):
    id: str
    email: Optional[str] = None
    full_name: Optional[str] = None
    role: str = "user"
    tier: str = "free"
    status: str = "active"
    is_suspended: bool = False
    is_online: bool = False
    last_active_at: Optional[datetime] = None
    last_login_at: Optional[datetime] = None
    suspended_until: Optional[datetime] = None
    suspension_reason: Optional[str] = None
    device_name: Optional[str] = None
    device_platform: Optional[str] = None
    created_at: Optional[datetime] = None
    today_messages_used: int = 0
    today_attachments_used: int = 0
    total_conversations: int = 0
    total_messages: int = 0
    stripe_subscription_status: Optional[str] = None


class AdminUsersListResponse(BaseModel):
    users: List[AdminUserItem]
    total_count: int
    page: int
    limit: int


class UpdateUserStatusRequest(BaseModel):
    is_suspended: bool
    status: Optional[str] = None # active, suspended, blocked
    duration_hours: Optional[int] = None
    reason: Optional[str] = None


class SuspendUserRequest(BaseModel):
    duration_hours: Optional[int] = None
    reason: str = Field(..., min_length=3)


class BlockUserRequest(BaseModel):
    reason: str = Field(..., min_length=3)


class UpdateUserTierRequest(BaseModel):
    tier: str = Field(..., pattern="^(free|premium|pro|vip|black)$")


class AdminFeedbackItem(BaseModel):
    id: str
    user_id: Optional[str] = None
    email: Optional[str] = None
    category: str
    subject: str
    description: str
    device_info: Optional[Dict[str, Any]] = None
    screenshot_url: Optional[str] = None
    status: str = "pending"
    admin_reply: Optional[str] = None
    replied_at: Optional[datetime] = None
    replied_by: Optional[str] = None
    created_at: datetime


class AdminFeedbackListResponse(BaseModel):
    feedback: List[AdminFeedbackItem]
    total_count: int
    page: int
    limit: int


class UpdateFeedbackStatusRequest(BaseModel):
    status: str = Field(..., pattern="^(pending|in_progress|resolved|closed)$")


class ReplyFeedbackRequest(BaseModel):
    reply: str = Field(..., min_length=3)


class AdminAlertItem(BaseModel):
    id: str
    type: str
    priority: str
    title: str
    message: str
    details: Optional[Dict[str, Any]] = None
    created_at: datetime


class AdminAlertsResponse(BaseModel):
    alerts: List[AdminAlertItem]
    total_unread: int


class SystemSettingsResponse(BaseModel):
    settings: Dict[str, Any]


class UpdateSystemSettingRequest(BaseModel):
    key: str = Field(..., pattern="^(maintenance_mode|registrations_open|min_app_version|global_announcement)$")
    value: Dict[str, Any]


class UpdatePlanRequest(BaseModel):
    price_monthly_cents: Optional[int] = None
    ai_queries_limit: Optional[int] = None
    ocr_pages_limit: Optional[int] = None
    is_active: Optional[bool] = None
    features: Optional[Dict[str, Any]] = None


class AdminSubscriptionItem(BaseModel):
    id: str
    user_id: str
    user_email: Optional[str] = None
    plan_id: str
    status: str
    stripe_customer_id: Optional[str] = None
    stripe_subscription_id: Optional[str] = None
    current_period_end: Optional[datetime] = None
    cancel_at_period_end: bool = False


class AiProviderConfig(BaseModel):
    id: str
    name: str
    provider_type: str
    is_active: bool
    model_name: str
    status: str
    masked_api_key: Optional[str] = None
    description: str


class QuotaSettings(BaseModel):
    free_messages_limit: int = 20
    free_attachments_limit: int = 3
    premium_messages_limit: int = 500
    premium_attachments_limit: int = 50
    max_attachment_size_mb: int = 10


class SystemErrorLogItem(BaseModel):
    id: str
    source: str
    error_type: str
    message: str
    user_id: Optional[str] = None
    created_at: datetime


class AdminAuditLogItem(BaseModel):
    id: str
    admin_id: str
    action: str
    target_type: Optional[str] = None
    target_id: Optional[str] = None
    details: Dict[str, Any] = Field(default_factory=dict)
    created_at: datetime


# ====================================================================
# MISSION 10 — SCHÉMAS D'ANALYTICS & USAGE IA
# ====================================================================

class AnalyticsSummary(BaseModel):
    total_requests: int
    success_requests: int
    error_requests: int
    streaming_interrupted: int
    success_rate_pct: float
    total_messages: int
    user_messages: int
    assistant_messages: int
    total_conversations: int
    total_prompt_tokens: int
    total_completion_tokens: int
    total_tokens: int
    avg_latency_ms: float
    median_latency_ms: float
    p95_latency_ms: float
    avg_ttft_ms: float
    estimated_cost_usd: float
    estimated_cost_eur: float
    total_attachments: int
    total_attachments_bytes: int


class AnalyticsTimeSeriesPoint(BaseModel):
    period_label: str
    requests: int
    messages: int
    tokens: int
    cost_usd: float
    avg_latency_ms: float
    errors: int


class TierAnalyticsItem(BaseModel):
    tier: str
    users_count: int
    messages_count: int
    requests_count: int
    tokens_count: int
    avg_messages_per_user: float
    quota_limit_per_user: int
    quota_used_today: int
    quota_remaining_today: int
    attachments_count: int
    estimated_cost_usd: float


class QuotaAnalytics(BaseModel):
    free_quota_consumed_today: int
    free_quota_pool_limit: int
    premium_quota_consumed_today: int
    premium_quota_pool_limit: int
    users_above_80_percent: int
    users_exhausted_quota: int
    top_quota_consumers: List[Dict[str, Any]]


class ErrorAnalyticsItem(BaseModel):
    error_type: str
    count: int
    percentage: float
    last_occurred: Optional[datetime] = None


class ErrorAnalytics(BaseModel):
    total_errors: int
    error_rate_pct: float
    by_type: List[ErrorAnalyticsItem]
    by_source: List[Dict[str, Any]]
    recent_errors: List[SystemErrorLogItem]


class PerformanceAnalytics(BaseModel):
    avg_latency_ms: float
    median_latency_ms: float
    p90_latency_ms: float
    p95_latency_ms: float
    p99_latency_ms: float
    avg_ttft_ms: float
    streaming_reliability_pct: float
    streaming_issues_count: int
    by_model: List[Dict[str, Any]]


class ConversationsAndAttachmentsAnalytics(BaseModel):
    total_conversations: int
    avg_messages_per_conversation: float
    max_messages_in_conversation: int
    total_attachments: int
    total_storage_bytes: int
    total_storage_mb: float
    mime_types: List[Dict[str, Any]]


class ProviderAnalyticsItem(BaseModel):
    provider: str
    model: str
    requests_count: int
    tokens_count: int
    avg_latency_ms: float
    estimated_cost_usd: float
    is_active: bool


class AdminAnalyticsResponse(BaseModel):
    period: str
    tier_filter: str
    provider_filter: str
    summary: AnalyticsSummary
    time_series: List[AnalyticsTimeSeriesPoint]
    tier_breakdown: Dict[str, TierAnalyticsItem]
    quota_analytics: QuotaAnalytics
    performance: PerformanceAnalytics
    errors_analytics: ErrorAnalytics
    conversations_attachments: ConversationsAndAttachmentsAnalytics
    providers: List[ProviderAnalyticsItem]

