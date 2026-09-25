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
    tier: str = "free"
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None


# Cache local des profils utilisateurs
_user_profile_cache: Dict[str, Any] = {}

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
                algorithms=["ES256", "RS256"],
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


def invalidate_user_profile_cache(user_id: Optional[str] = None) -> None:
    """Invalide le cache local de profil utilisateur."""
    global _user_profile_cache
    if user_id:
        _user_profile_cache.pop(str(user_id), None)
    else:
        _user_profile_cache.clear()


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

    # Vérification d'état, de blocage/suspension et de rôle avec cache mémoire 30s
    from app.database.connection import db_manager
    from datetime import datetime, timezone
    import time
    import json

    db_role = payload.get("role", "authenticated")
    db_tier = "free"

    global _user_profile_cache, _maintenance_cache
    if "_user_profile_cache" not in globals():
        _user_profile_cache = {}
    if "_maintenance_cache" not in globals():
        _maintenance_cache = {"enabled": False, "message": "", "time": 0}

    now = time.time()
    now_utc = datetime.now(timezone.utc)

    # 1. Vérification du mode maintenance (cache 15s)
    if now - _maintenance_cache["time"] > 15:
        try:
            with db_manager.connect() as conn:
                m_rows = conn.run("SELECT value FROM public.system_settings WHERE key = 'maintenance_mode'")
                if m_rows and m_rows[0][0]:
                    val = m_rows[0][0]
                    if isinstance(val, str):
                        val = json.loads(val)
                    _maintenance_cache["enabled"] = bool(val.get("enabled", False))
                    _maintenance_cache["message"] = str(val.get("message", "SD CHAT AI est actuellement en maintenance."))
                    _maintenance_cache["time"] = now
        except Exception as m_err:
            logger.debug("Vérification maintenance_mode: %s", m_err)

    cached = _user_profile_cache.get(str(user_id))
    if cached and (now - cached["time"] < 30):
        db_role = cached["role"]
        db_tier = cached["tier"]
        acc_status = cached.get("status", "active")
        if acc_status == "blocked":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Votre compte a été bloqué définitivement. Raison: {cached.get('reason') or 'Non spécifiée'}"
            )
        if acc_status == "suspended" or cached.get("is_suspended"):
            susp_until = cached.get("suspended_until")
            if susp_until and susp_until > now_utc:
                exp_str = susp_until.strftime("%d/%m/%Y à %H:%M UTC")
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Votre compte est temporairement suspendu jusqu'au {exp_str}. Raison: {cached.get('reason') or 'Non spécifiée'}"
                )
            elif not susp_until:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Votre compte a été suspendu par un administrateur. Raison: {cached.get('reason') or 'Non spécifiée'}"
                )
    else:
        try:
            with db_manager.connect() as conn:
                rows = conn.run(
                    """
                    SELECT role, is_suspended, tier, status, suspended_until, suspension_reason, last_active_at
                    FROM public.profiles 
                    WHERE id = :uid
                    """,
                    uid=str(user_id)
                )
                if rows:
                    row_role, is_suspended, row_tier, r_status, r_susp_until, r_reason, r_last_active = rows[0]
                    r_status = r_status or ("suspended" if is_suspended else "active")
                    
                    # Vérifier si compte bloqué
                    if r_status == "blocked":
                        _user_profile_cache[str(user_id)] = {
                            "role": row_role or "user",
                            "is_suspended": True,
                            "status": "blocked",
                            "reason": r_reason,
                            "tier": row_tier or "free",
                            "time": now,
                        }
                        raise HTTPException(
                            status_code=status.HTTP_403_FORBIDDEN,
                            detail=f"Votre compte a été bloqué définitivement. Raison: {r_reason or 'Non spécifiée'}"
                        )
                    
                    # Vérifier si compte suspendu
                    if r_status == "suspended" or is_suspended is True:
                        if r_susp_until and r_susp_until > now_utc:
                            _user_profile_cache[str(user_id)] = {
                                "role": row_role or "user",
                                "is_suspended": True,
                                "status": "suspended",
                                "suspended_until": r_susp_until,
                                "reason": r_reason,
                                "tier": row_tier or "free",
                                "time": now,
                            }
                            exp_str = r_susp_until.strftime("%d/%m/%Y à %H:%M UTC")
                            raise HTTPException(
                                status_code=status.HTTP_403_FORBIDDEN,
                                detail=f"Votre compte est temporairement suspendu jusqu'au {exp_str}. Raison: {r_reason or 'Non spécifiée'}"
                            )
                        elif r_susp_until and r_susp_until <= now_utc:
                            # Levée automatique de la suspension expirée
                            conn.run(
                                """
                                UPDATE public.profiles 
                                SET status = 'active', is_suspended = false, suspended_until = NULL, suspension_reason = NULL, updated_at = NOW() 
                                WHERE id = :uid
                                """,
                                uid=str(user_id)
                            )
                            r_status = "active"
                            is_suspended = False
                        else:
                            _user_profile_cache[str(user_id)] = {
                                "role": row_role or "user",
                                "is_suspended": True,
                                "status": "suspended",
                                "reason": r_reason,
                                "tier": row_tier or "free",
                                "time": now,
                            }
                            raise HTTPException(
                                status_code=status.HTTP_403_FORBIDDEN,
                                detail=f"Votre compte a été suspendu par un administrateur. Raison: {r_reason or 'Non spécifiée'}"
                            )

                    if row_role:
                        db_role = row_role
                    if row_tier:
                        db_tier = row_tier

                    # Mettre à jour last_active_at si > 60s
                    last_active_ts = r_last_active.timestamp() if r_last_active else 0
                    if now - last_active_ts > 60:
                        try:
                            conn.run("UPDATE public.profiles SET last_active_at = NOW() WHERE id = :uid", uid=str(user_id))
                        except Exception:
                            pass

                    _user_profile_cache[str(user_id)] = {
                        "role": db_role,
                        "is_suspended": False,
                        "status": "active",
                        "tier": db_tier,
                        "time": now,
                    }
        except HTTPException:
            raise
        except Exception as e:
            logger.warning("Erreur vérification profil pour %s: %s", user_id, e)

    # Bloquer les non-admins si maintenance active
    if _maintenance_cache.get("enabled") and db_role != "admin":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=_maintenance_cache.get("message") or "SD CHAT AI est temporairement en maintenance."
        )

    return AuthenticatedUser(
        id=str(user_id),
        email=payload.get("email"),
        role=db_role,
        tier=db_tier,
        full_name=payload.get("user_metadata", {}).get("full_name"),
        avatar_url=payload.get("user_metadata", {}).get("avatar_url"),
    )


async def get_current_user_optional(
    authorization: Optional[str] = Header(None)
) -> Optional[AuthenticatedUser]:
    """Extrait l'utilisateur authentifié s'il est présent, sans lever 401 si absent."""
    if not authorization:
        return None
    try:
        return await get_current_user(authorization=authorization)
    except HTTPException:
        return None


async def get_current_admin_user(
    authorization: Optional[str] = Header(None)
) -> AuthenticatedUser:
    """
    Dépendance stricte de sécurité réservée aux administrateurs.
    Exige un utilisateur connecté ET dont le rôle est 'admin' validé côté serveur dans Supabase.
    """
    user = await get_current_user(authorization)

    # Double vérification stricte en base de données
    from app.database.connection import db_manager
    with db_manager.connect() as conn:
        rows = conn.run(
            "SELECT role, is_suspended FROM public.profiles WHERE id = :uid",
            uid=user.id
        )
        if not rows:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Accès interdit. Profil administrateur introuvable."
            )
        role, is_suspended = rows[0]
        if is_suspended:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Accès interdit. Compte administrateur suspendu."
            )
        if role != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Accès interdit. Privilèges administrateur requis."
            )

    return user


def create_admin_access_token(user_id: str, email: str, expires_delta_hours: int = 24) -> str:
    """Génère un jeton JWT d'administration sécurisé signé côté backend."""
    from datetime import datetime, timezone, timedelta
    expire = datetime.now(timezone.utc) + timedelta(hours=expires_delta_hours)
    to_encode = {
        "sub": user_id,
        "email": email,
        "role": "admin",
        "exp": int(expire.timestamp()),
        "iat": int(datetime.now(timezone.utc).timestamp()),
        "iss": "sd-chat-ai-admin",
    }
    secret = settings.supabase_jwt_secret or "super-secret-jwt-token-sd-dev-2026"
    return jwt.encode(to_encode, secret, algorithm="HS256")

