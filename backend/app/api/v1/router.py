from fastapi import APIRouter
from app.api.v1.endpoints.chat import router as chat_router
from app.api.v1.endpoints.conversations import router as conversations_router
from app.api.v1.endpoints.attachments import router as attachments_router
from app.api.v1.endpoints.quota import router as quota_router
from app.api.v1.endpoints.billing import router as billing_router
from app.api.v1.endpoints.admin import router as admin_router
from app.api.v1.endpoints.health import router as health_router
from app.api.auth import router as auth_router
from app.api.v1.endpoints.user_settings import router as settings_router

api_v1_router = APIRouter(prefix="/v1")

api_v1_router.include_router(health_router)
api_v1_router.include_router(chat_router)
api_v1_router.include_router(conversations_router)
api_v1_router.include_router(attachments_router)
api_v1_router.include_router(quota_router)
api_v1_router.include_router(billing_router)
api_v1_router.include_router(admin_router)
api_v1_router.include_router(auth_router)
api_v1_router.include_router(settings_router)


