from fastapi import APIRouter

router = APIRouter()

@router.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "SD CHAT AI",
        "version": "0.1.0"
    }
