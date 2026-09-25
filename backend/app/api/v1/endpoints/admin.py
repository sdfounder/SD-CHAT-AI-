import logging
from typing import List, Optional
from fastapi import APIRouter, Depends, Request, status, Query

from app.core.security import get_current_admin_user, AuthenticatedUser
from app.schemas.admin_schemas import (
    AdminLoginRequest,
    AdminGoogleLoginRequest,
    AdminRegisterRequest,
    AdminStatusResponse,
    AdminLoginResponse,
    AdminStatsResponse,
    AdminUsersListResponse,
    UpdateUserStatusRequest,
    SuspendUserRequest,
    BlockUserRequest,
    UpdateUserTierRequest,
    AdminSubscriptionItem,
    AiProviderConfig,
    QuotaSettings,
    SystemErrorLogItem,
    AdminAuditLogItem,
    AdminAnalyticsResponse,
    AdminFeedbackListResponse,
    UpdateFeedbackStatusRequest,
    ReplyFeedbackRequest,
    AdminAlertsResponse,
    SystemSettingsResponse,
    UpdateSystemSettingRequest,
    UpdatePlanRequest,
)

from app.services.admin_service import AdminService
from app.ai.gateway import ai_gateway_router, circuit_breaker, PlanEngine
from app.ai.models_catalog import ModelsCatalog

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["Administration Dashboard"])


@router.get(
    "/auth/status",
    response_model=AdminStatusResponse,
    summary="État de l'initialisation administrateur",
    description="Indique si un administrateur officiel est déjà enregistré ou si l'inscription initiale est ouverte.",
)
async def get_admin_auth_status():
    status_info = AdminService.get_admin_status()
    return AdminStatusResponse(**status_info)


@router.post(
    "/auth/register",
    response_model=AdminLoginResponse,
    summary="Inscription du premier administrateur officiel",
    description="Permet au premier administrateur de s'inscrire via Email/Mot de passe. L'inscription est ensuite définitivement close.",
)
async def admin_register(request_data: AdminRegisterRequest, request: Request):
    client_ip = request.client.host if request.client else None
    result = AdminService.register_first_admin(
        email=request_data.email,
        password=request_data.password,
        full_name=request_data.full_name,
        user_id=request_data.user_id,
        ip_address=client_ip,
    )
    return AdminLoginResponse(**result)


@router.post(
    "/auth/login",
    response_model=AdminLoginResponse,
    summary="Authentification administrateur",
    description="Vérifie les identifiants d'administration et génère un jeton JWT avec le rôle 'admin'.",
)
async def admin_login(request_data: AdminLoginRequest, request: Request):
    client_ip = request.client.host if request.client else None
    result = AdminService.authenticate_admin(
        email=request_data.email,
        password=request_data.password,
        ip_address=client_ip,
    )
    return AdminLoginResponse(**result)


@router.post(
    "/auth/google",
    summary="Authentification administrateur via Google Auth (Désactivée)",
    description="Google Auth est strictement interdit sur la console d'administration.",
)
async def admin_google_login():
    from fastapi import HTTPException
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="L'authentification Google est désactivée sur la console d'administration. Utilisez exclusivement Email et Mot de passe."
    )


@router.get(
    "/auth/me",
    summary="Consulter le profil de l'administrateur connecté",
)
async def get_admin_me(current_admin: AuthenticatedUser = Depends(get_current_admin_user)):
    return {
        "id": current_admin.id,
        "email": current_admin.email,
        "role": current_admin.role,
        "full_name": current_admin.full_name or "Administrateur SD",
    }


@router.get(
    "/stats",
    response_model=AdminStatsResponse,
    summary="Statistiques consolidées en temps réel",
)
async def get_stats(current_admin: AuthenticatedUser = Depends(get_current_admin_user)):
    return AdminService.get_stats()


@router.get(
    "/analytics",
    response_model=AdminAnalyticsResponse,
    summary="Statistiques approfondies d'utilisation et d'inférence IA",
    description="Retourne les KPI réels d'usage Gemini, volumétries temporelles, répartition Free vs Premium, latences et coûts.",
)
async def get_analytics(
    period: str = Query("7d", pattern="^(24h|7d|30d|90d|all)$", description="Période d'analyse"),
    tier: str = Query("all", pattern="^(all|free|premium)$", description="Filtre formule utilisateur"),
    provider: str = Query("all", pattern="^(all|gemini|sd_core)$", description="Filtre fournisseur IA"),
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    return AdminService.get_analytics(
        period=period,
        tier_filter=tier,
        provider_filter=provider,
    )



@router.get(
    "/users",
    response_model=AdminUsersListResponse,
    summary="Liste paginée des utilisateurs et suivi des quotas",
)
async def list_users(
    q: Optional[str] = Query(None, description="Recherche par email ou nom"),
    tier: Optional[str] = Query(None, description="Filtre par formule (free, premium, pro)"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filtre par état (active, suspended)"),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    return AdminService.list_users(
        search=q,
        tier=tier,
        status_filter=status_filter,
        page=page,
        limit=limit,
    )


@router.post(
    "/users/{user_id}/status",
    summary="Suspendre, bloquer ou réactiver un compte utilisateur",
)
async def update_user_status(
    user_id: str,
    body: UpdateUserStatusRequest,
    request: Request,
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    client_ip = request.client.host if request.client else None
    return AdminService.update_user_status(
        admin_id=current_admin.id,
        user_id=user_id,
        is_suspended=body.is_suspended,
        status_val=body.status,
        duration_hours=body.duration_hours,
        reason=body.reason,
        ip_address=client_ip,
    )


@router.post(
    "/users/{user_id}/suspend",
    summary="Suspendre temporairement un compte avec durée et motif",
)
async def suspend_user(
    user_id: str,
    body: SuspendUserRequest,
    request: Request,
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    client_ip = request.client.host if request.client else None
    return AdminService.suspend_user(
        admin_id=current_admin.id,
        user_id=user_id,
        duration_hours=body.duration_hours,
        reason=body.reason,
        ip_address=client_ip,
    )


@router.post(
    "/users/{user_id}/block",
    summary="Bloquer définitivement un compte utilisateur (motif obligatoire)",
)
async def block_user(
    user_id: str,
    body: BlockUserRequest,
    request: Request,
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    client_ip = request.client.host if request.client else None
    return AdminService.block_user(
        admin_id=current_admin.id,
        user_id=user_id,
        reason=body.reason,
        ip_address=client_ip,
    )


@router.post(
    "/users/{user_id}/unblock",
    summary="Réactiver un compte suspendu ou bloqué",
)
async def unblock_user(
    user_id: str,
    request: Request,
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    client_ip = request.client.host if request.client else None
    return AdminService.unblock_user(
        admin_id=current_admin.id,
        user_id=user_id,
        ip_address=client_ip,
    )


@router.post(
    "/users/{user_id}/tier",
    summary="Ajuster la formule utilisateur (Free / Premium)",
)
async def update_user_tier(
    user_id: str,
    body: UpdateUserTierRequest,
    request: Request,
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    client_ip = request.client.host if request.client else None
    return AdminService.update_user_tier(
        admin_id=current_admin.id,
        user_id=user_id,
        tier=body.tier,
        ip_address=client_ip,
    )


@router.get(
    "/subscriptions",
    response_model=List[AdminSubscriptionItem],
    summary="Liste des abonnements réels synchronisés avec Stripe",
)
async def list_subscriptions(current_admin: AuthenticatedUser = Depends(get_current_admin_user)):
    return AdminService.list_subscriptions()


@router.get(
    "/ai/providers",
    response_model=List[AiProviderConfig],
    summary="État et configuration des providers IA",
)
async def get_ai_providers(current_admin: AuthenticatedUser = Depends(get_current_admin_user)):
    return AdminService.get_ai_providers()


@router.get(
    "/ai/quotas",
    response_model=QuotaSettings,
    summary="Configuration actuelle des quotas globaux",
)
async def get_quota_settings(current_admin: AuthenticatedUser = Depends(get_current_admin_user)):
    return AdminService.get_quota_settings()


@router.patch(
    "/ai/quotas",
    response_model=QuotaSettings,
    summary="Mettre à jour les quotas par défaut du système",
)
async def update_quota_settings(
    body: QuotaSettings,
    request: Request,
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    client_ip = request.client.host if request.client else None
    return AdminService.update_quota_settings(
        admin_id=current_admin.id,
        new_settings=body,
        ip_address=client_ip,
    )


@router.get(
    "/logs/errors",
    response_model=List[SystemErrorLogItem],
    summary="Journal des erreurs système et IA",
)
async def list_error_logs(
    limit: int = Query(50, ge=1, le=200),
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    return AdminService.list_error_logs(limit=limit)


@router.get(
    "/logs/audit",
    response_model=List[AdminAuditLogItem],
    summary="Piste d'audit des opérations administratives",
)
async def list_audit_logs(
    limit: int = Query(50, ge=1, le=200),
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    return AdminService.list_audit_logs(limit=limit)


# ====================================================================
# SD AI GATEWAY — ADMINISTRATION & SUPERVISION
# ====================================================================

@router.get("/gateway/status", summary="Statut consolidé SD AI Gateway")
async def get_gateway_status(current_admin: AuthenticatedUser = Depends(get_current_admin_user)):
    return {
        "providers": ai_gateway_router.get_all_provider_statuses(),
        "total_active_models": len(ModelsCatalog.list_active_models()),
        "plans": [PlanEngine.get_plan_limits(p) for p in ("free", "premium", "vip", "black")],
    }


@router.post("/gateway/providers/{provider}/toggle", summary="Activer ou désactiver manuellement un fournisseur IA")
async def toggle_gateway_provider(
    provider: str,
    disabled: bool = Query(...),
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    circuit_breaker.set_manual_override(provider, disabled)
    return {"provider": provider, "manually_disabled": disabled, "status": "updated"}


@router.post("/gateway/providers/{provider}/test", summary="Tester la validité des identifiants d'un fournisseur côté serveur")
async def test_gateway_provider(
    provider: str,
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    inst = ai_gateway_router.get_provider_instance(provider)
    if not inst:
        return {"provider": provider, "valid": False, "error": "Fournisseur inconnu"}
    is_valid = await inst.validate_credentials()
    return {"provider": provider, "valid": is_valid}


@router.get("/gateway/models", summary="Catalogue complet des modèles (actifs et non disponibles)")
async def get_gateway_models(current_admin: AuthenticatedUser = Depends(get_current_admin_user)):
    return ModelsCatalog.list_all_models_for_admin()


@router.get("/gateway/plans", summary="Plans officiels SD et quotas")
async def get_gateway_plans(current_admin: AuthenticatedUser = Depends(get_current_admin_user)):
    return [PlanEngine.get_plan_limits(p) for p in ("free", "premium", "vip", "black")]


@router.patch("/gateway/plans/{plan_id}", summary="Modifier les limites et tarifs d'un plan")
async def update_gateway_plan(
    plan_id: str,
    body: UpdatePlanRequest,
    request: Request,
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    client_ip = request.client.host if request.client else None
    return AdminService.update_plan(
        admin_id=current_admin.id,
        plan_id=plan_id,
        price_monthly_cents=body.price_monthly_cents,
        ai_queries_limit=body.ai_queries_limit,
        ocr_pages_limit=body.ocr_pages_limit,
        is_active=body.is_active,
        features=body.features,
        ip_address=client_ip,
    )


# ====================================================================
# CENTRE DE COMMENTAIRES & SIGNALEMENTS (FEEDBACK)
# ====================================================================

@router.get(
    "/feedback",
    response_model=AdminFeedbackListResponse,
    summary="Liste paginée des commentaires et signalements des utilisateurs",
)
async def list_feedback(
    status_filter: Optional[str] = Query(None, alias="status"),
    category: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    return AdminService.list_feedback(
        status_filter=status_filter,
        category=category,
        page=page,
        limit=limit,
    )


@router.patch(
    "/feedback/{feedback_id}/status",
    summary="Modifier le statut d'un commentaire utilisateur",
)
async def update_feedback_status(
    feedback_id: str,
    body: UpdateFeedbackStatusRequest,
    request: Request,
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    client_ip = request.client.host if request.client else None
    return AdminService.update_feedback_status(
        admin_id=current_admin.id,
        feedback_id=feedback_id,
        status_val=body.status,
        ip_address=client_ip,
    )


@router.post(
    "/feedback/{feedback_id}/reply",
    summary="Répondre à un commentaire et notifier l'utilisateur in-app",
)
async def reply_feedback(
    feedback_id: str,
    body: ReplyFeedbackRequest,
    request: Request,
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    client_ip = request.client.host if request.client else None
    return AdminService.reply_feedback(
        admin_id=current_admin.id,
        feedback_id=feedback_id,
        reply=body.reply,
        ip_address=client_ip,
    )


# ====================================================================
# ALERTES SYSTÈME ET SURVEILLANCE
# ====================================================================

@router.get(
    "/alerts",
    response_model=AdminAlertsResponse,
    summary="Alertes système en temps réel (erreurs, disjoncteurs IA, signalements)",
)
async def get_admin_alerts(current_admin: AuthenticatedUser = Depends(get_current_admin_user)):
    return AdminService.get_alerts()


# ====================================================================
# PARAMÈTRES SYSTÈME (MAINTENANCE, INSCRIPTIONS, ANNONCE)
# ====================================================================

@router.get(
    "/settings",
    response_model=SystemSettingsResponse,
    summary="Consulter les paramètres système globaux",
)
async def get_system_settings(current_admin: AuthenticatedUser = Depends(get_current_admin_user)):
    return AdminService.get_settings()


@router.patch(
    "/settings",
    summary="Modifier un paramètre système (mode maintenance, version minimale, etc.)",
)
async def update_system_setting(
    body: UpdateSystemSettingRequest,
    request: Request,
    current_admin: AuthenticatedUser = Depends(get_current_admin_user),
):
    client_ip = request.client.host if request.client else None
    return AdminService.update_setting(
        admin_id=current_admin.id,
        key=body.key,
        value=body.value,
        ip_address=client_ip,
    )

