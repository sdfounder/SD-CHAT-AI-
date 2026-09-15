from fastapi import APIRouter
from app.core.config import settings
from app.database.connection import db_manager

router = APIRouter(tags=["Health"])


@router.get("/health", summary="Vérification de l'état du service et des connexions")
async def health_check():
    db_status = "unknown"
    try:
        with db_manager.connect() as conn:
            conn.run("SELECT 1")
            db_status = "connected"
    except Exception as e:
        db_status = f"error: {str(e)}"

    return {
        "status": "online",
        "service": "SD CHAT AI Backend",
        "version": "1.0.0",
        "environment": settings.environment,
        "database": db_status,
        "ai_provider": "gemini",
        "ai_model": settings.gemini_model,
    }
