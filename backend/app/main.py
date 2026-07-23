from fastapi import FastAPI

from app.api.health import router as health_router
from app.api.chat import router as chat_router
from app.api import auth

app = FastAPI(
    title="SD CHAT AI",
    version="0.1.0"
)

@app.get("/")
def home():
    return {
        "message": "Bonjour, je suis SD CHAT AI, votre IA personnelle.",
        "version": "0.1.0",
        "status": "online"
    }

app.include_router(health_router, prefix="/api")
app.include_router(chat_router, prefix="/api")
app.include_router(auth.router, prefix="/api")
