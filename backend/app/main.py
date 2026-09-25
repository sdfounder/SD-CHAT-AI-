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

# Limiteur de débit contre les abus et le déni de service (DoS)
from app.core.rate_limiter import RateLimitMiddleware
app.add_middleware(RateLimitMiddleware)

# Configuration CORS sécurisée pour Flutter mobile et web
is_wildcard = "*" in settings.cors_origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=not is_wildcard,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)


# En-têtes HTTP de sécurité (OWASP Secure Headers)
from fastapi import Request

@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    if settings.environment == "production":
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response

# Montage du routeur v1 (compatibilité /api/v1 et /v1)
app.include_router(api_v1_router, prefix="/api")
app.include_router(api_v1_router)

# Montage direct du routeur d'administration (/api/admin et /admin/auth/...)
from app.api.v1.endpoints.admin import router as admin_router
app.include_router(admin_router, prefix="/api")
app.include_router(admin_router)


import os
from fastapi.responses import HTMLResponse

ADMIN_HTML_PATH = os.path.join(os.path.dirname(__file__), "static", "admin", "index.html")


@app.get("/admin", response_class=HTMLResponse, include_in_schema=False)
@app.get("/admin/", response_class=HTMLResponse, include_in_schema=False)
def serve_admin():
    """Sert l'interface web de la console d'administration SD CHAT AI."""
    if os.path.exists(ADMIN_HTML_PATH):
        with open(ADMIN_HTML_PATH, "r", encoding="utf-8") as f:
            return HTMLResponse(content=f.read())
    return HTMLResponse(content="<h1>Console d'administration introuvable</h1>", status_code=404)


@app.get("/", tags=["Root"])
def root_endpoint():
    return {
        "app": "SD CHAT AI",
        "creator": "Sekou Diaby",
        "slogan": "SD — Build the Future with AI",
        "version": "1.0.0",
        "status": "online",
        "admin_console": "/admin",
        "documentation": "/docs" if settings.environment != "production" else "disabled"
    }

