import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.api.v1.router import api_v1_router

logging.basicConfig(
    level=logging.INFO if settings.environment == "production" else logging.DEBUG,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("sd_chat_ai")

app = FastAPI(
    title="SD CHAT AI API",
    description="Backend officiel de SD CHAT AI — Écosystème SD (Sekou Diaby)",
    version="1.0.0",
    docs_url="/docs" if settings.environment != "production" else None,
    redoc_url="/redoc" if settings.environment != "production" else None,
)

# Configuration CORS pour Flutter mobile et web
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Montage du routeur v1
app.include_router(api_v1_router, prefix="/api")


@app.get("/", tags=["Root"])
def root_endpoint():
    return {
        "app": "SD CHAT AI",
        "creator": "Sekou Diaby",
        "slogan": "SD — Build the Future with AI",
        "version": "1.0.0",
        "status": "online",
        "documentation": "/docs" if settings.environment != "production" else "disabled"
    }
