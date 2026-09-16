import logging
from fastapi import APIRouter, Depends

from app.core.security import get_current_user, AuthenticatedUser
from app.schemas.chat_schemas import QuotaStatusResponse
from app.services.quota_service import QuotaService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/quota", tags=["Quotas & Plans"])


@router.get("", response_model=QuotaStatusResponse, summary="Obtenir l'état du quota et du plan de l'utilisateur")
async def get_user_quota(
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Renvoie le plan actuel ('free' ou 'premium'), les compteurs de messages et pièces jointes,
    ainsi que l'heure exacte de la prochaine réinitialisation journalière UTC.
    """
    return QuotaService.get_quota_status(current_user.id)
