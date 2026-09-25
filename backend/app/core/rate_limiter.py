import time
import threading
from typing import Dict, Tuple, List, Optional
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

class RateLimiter:
    """
    Limiteur de débit mémoire glissant (Sliding Window Counter) thread-safe.
    Protège les endpoints sensibles contre le brute-force, le spam et le déni de service (DoS).
    """

    def __init__(self):
        self._lock = threading.Lock()
        # Clé: (ip_or_user, endpoint_bucket) -> liste des timestamps d'appels récents
        self._access_records: Dict[Tuple[str, str], List[float]] = {}
        self._last_cleanup = time.time()

        # Règles de limitation par préfixe d'URI (nombre_max_requetes, fenetre_en_secondes)
        self.rules: Dict[str, Tuple[int, int]] = {
            "/api/v1/admin/auth/login": (5, 60),      # Max 5 tentatives par minute
            "/api/v1/attachments/upload": (30, 60),   # Max 30 uploads par minute
            "/api/v1/chat/stream": (60, 60),          # Max 60 requêtes de streaming par minute
            "/api/v1/billing/checkout": (15, 60),     # Max 15 sessions checkout par minute
        }
        self.default_rule = (300, 60)  # Règle globale par défaut (300 req / minute)

    def _cleanup_expired(self, now: float):
        """Nettoie les enregistrements expirés toutes les 5 minutes pour libérer la mémoire."""
        if now - self._last_cleanup < 300:
            return
        self._last_cleanup = now
        stale_keys = []
        for key, timestamps in self._access_records.items():
            valid_timestamps = [t for t in timestamps if now - t < 120]
            if not valid_timestamps:
                stale_keys.append(key)
            else:
                self._access_records[key] = valid_timestamps
        for k in stale_keys:
            del self._access_records[k]

    def is_allowed(self, client_id: str, path: str) -> Tuple[bool, int]:
        """
        Vérifie si la requête est autorisée.
        Retourne (is_allowed, retry_after_seconds).
        """
        now = time.time()
        
        # Trouver la règle applicable
        limit, window = self.default_rule
        matched_rule_key = "default"
        for rule_path, rule in self.rules.items():
            if path.startswith(rule_path):
                limit, window = rule
                matched_rule_key = rule_path
                break

        key = (client_id, matched_rule_key)

        with self._lock:
            self._cleanup_expired(now)

            timestamps = self._access_records.get(key, [])
            # Filtrer les timestamps dans la fenêtre
            window_start = now - window
            recent = [t for t in timestamps if t > window_start]

            if len(recent) >= limit:
                oldest_in_window = recent[0]
                retry_after = max(1, int(window - (now - oldest_in_window)))
                return False, retry_after

            recent.append(now)
            self._access_records[key] = recent
            return True, 0


rate_limiter = RateLimiter()


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Middleware Starlette/FastAPI appliquant le RateLimiter."""

    async def dispatch(self, request: Request, call_next):
        # Ne pas limiter les requêtes CORS OPTIONS pré-vol
        if request.method == "OPTIONS":
            return await call_next(request)

        path = request.url.path

        # Exclusion des endpoints de monitoring et fichiers statiques
        if path in ("/", "/api/v1/health", "/docs", "/redoc", "/openapi.json") or path.startswith("/admin"):
            return await call_next(request)

        # Identifier le client (IP de connexion ou en-tête de proxy de confiance)
        forwarded = request.headers.get("X-Forwarded-For")
        client_ip = forwarded.split(",")[0].strip() if forwarded else (request.client.host if request.client else "unknown")

        allowed, retry_after = rate_limiter.is_allowed(client_ip, path)
        if not allowed:
            return JSONResponse(
                status_code=429,
                content={
                    "detail": "Limite de requêtes atteinte. Veuillez patienter avant de réessayer.",
                    "retry_after_seconds": retry_after,
                },
                headers={"Retry-After": str(retry_after)}
            )

        return await call_next(request)
