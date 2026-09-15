import logging
from typing import Optional, Dict, Any
import jwt
from pydantic import BaseModel
from fastapi import HTTPException, status, Header

from app.core.config import settings

logger = logging.getLogger(__name__)


class AuthenticatedUser(BaseModel):
    id: str
    email: Optional[str] = None
    role: str = "user"
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None


# Client JWKS Supabase pour vérification cryptographique des jetons asymétriques (ES256/RS256)
_jwks_client: Optional[jwt.PyJWKClient] = None

def get_jwks_client() -> Optional[jwt.PyJWKClient]:
    global _jwks_client
    if _jwks_client is None and settings.supabase_url:
        try:
            jwks_url = f"{settings.supabase_url.rstrip('/')}/auth/v1/.well-known/jwks.json"
            _jwks_client = jwt.PyJWKClient(jwks_url, cache_jwk_set=True, lifespan=3600)
        except Exception as e:
            logger.warning("Impossible d'initialiser le client JWKS Supabase: %s", e)
    return _jwks_client


def decode_supabase_jwt(token: str) -> Dict[str, Any]:
    """
    Décode et valide cryptographiquement un jeton JWT Supabase :
    1. Validation dev explicite si environnement dev
    2. Validation asymétrique via JWKS Supabase officiel (ES256/RS256)
    3. Validation symétrique via secret Supabase (HS256)
    """
    # Mode développement / tests : support de tokens de dev explicites
    if settings.environment == "development":
        if token.startswith("dev-token-") or token.startswith("fake-token-"):
            user_id = token.replace("dev-token-", "").replace("fake-token-", "")
            return {
                "sub": user_id,
                "email": f"{user_id}@sd-chat.ai",
                "role": "authenticated",
            }

    # 1. Tentative de validation asymétrique via JWKS Supabase
    jwks = get_jwks_client()
    if jwks:
        try:
            signing_key = jwks.get_signing_key_from_jwt(token)
            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=["ES256", "RS256", "HS256"],
                options={"verify_aud": False}
            )
            return payload
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Jeton d'authentification expiré",
            )
        except Exception:
            # Si échec JWKS, tester via secret symétrique ci-dessous
            pass

    # 2. Tentative avec secret JWT symétrique (HS256)
    try:
        if settings.supabase_jwt_secret and settings.supabase_jwt_secret != "placeholder-jwt-secret":
            payload = jwt.decode(
                token,
                settings.supabase_jwt_secret,
                algorithms=["HS256"],
                options={"verify_aud": False}
            )
            return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Jeton d'authentification expiré",
        )
    except Exception as e:
        logger.error("Erreur validation JWT HS256: %s", str(e))

    # 3. Fallback dev si aucun secret configuré
    if settings.environment == "development":
        try:
            return jwt.decode(token, options={"verify_signature": False})
        except Exception:
            pass

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Jeton d'authentification invalide ou signature non reconnue",
    )


async def get_current_user(authorization: Optional[str] = Header(None)) -> AuthenticatedUser:
    """
    Dépendance FastAPI pour extraire l'utilisateur courant depuis l'en-tête Authorization.
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="En-tête d'autorisation manquant (Bearer token requis)",
        )

    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Format du jeton invalide (doit être 'Bearer <token>')",
        )

    token = parts[1]
    payload = decode_supabase_jwt(token)
    user_id = payload.get("sub") or payload.get("id")

    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identifiant utilisateur introuvable dans le jeton",
        )

    return AuthenticatedUser(
        id=str(user_id),
        email=payload.get("email"),
        role=payload.get("role", "authenticated"),
        full_name=payload.get("user_metadata", {}).get("full_name"),
        avatar_url=payload.get("user_metadata", {}).get("avatar_url"),
    )
