import logging
from typing import Dict, Any, List, Optional
from app.ai.models_catalog import ModelsCatalog

logger = logging.getLogger(__name__)


class PlanTier:
    FREE = "free"
    PREMIUM = "premium"
    VIP = "vip"
    BLACK = "black"


class PlanEngine:

    """
    Moteur de contrôle d'accès aux modèles et fonctionnalités par niveau d'abonnement SD.
    Plans officiels :
    1. FREE (0 GNF) : 5 requêtes/jour, modèle Gemini économique, pas de sélection manuelle.
    2. PREMIUM (10 000 GNF/mois) : 10 requêtes/jour, modèles premium, sélection auto Gateway.
    3. VIP (50 000 GNF/mois) : 25 requêtes/jour, sélection manuelle du catalogue VIP, fallback auto.
    4. BLACK (250 000 GNF/mois) : Haute capacité Fair Use, modèles haut de gamme, priorité maximale.
    """

    PLAN_LEVELS: Dict[str, int] = {
        "free": 1,
        "premium": 2,
        "pro": 2,      # Alias de compatibilité avec les anciens abonnements
        "vip": 3,
        "black": 4,
        "ultra": 4,    # Alias
    }

    PLAN_LIMITS: Dict[str, Dict[str, Any]] = {
        "free": {
            "name": "SD FREE",
            "daily_messages_limit": 5,
            "daily_attachments_limit": 3,
            "max_attachment_size_mb": 10,
            "supports_memory": False,
            "can_select_model": False,
            "default_model": "gemini-3.6-flash",
            "fair_use_daily_cap": 5,
            "price_gnf": 0,
        },
        "premium": {
            "name": "SD PREMIUM",
            "daily_messages_limit": 10,
            "daily_attachments_limit": 50,
            "max_attachment_size_mb": 15,
            "supports_memory": True,
            "can_select_model": False,
            "default_model": "gemini-3.6-flash",
            "fair_use_daily_cap": 10,
            "price_gnf": 10000,
        },
        "vip": {
            "name": "SD VIP",
            "daily_messages_limit": 25,
            "daily_attachments_limit": 100,
            "max_attachment_size_mb": 25,
            "supports_memory": True,
            "can_select_model": True,
            "default_model": "gemini-3.6-flash",
            "fair_use_daily_cap": 25,
            "price_gnf": 50000,
        },
        "black": {
            "name": "SD BLACK PREMIUM ULTRA",
            "daily_messages_limit": 200,  # Plafond Fair Use interne
            "daily_attachments_limit": 500,
            "max_attachment_size_mb": 50,
            "supports_memory": True,
            "can_select_model": True,
            "default_model": "gemini-3.6-flash",
            "fair_use_daily_cap": 200,
            "price_gnf": 250000,
        },
    }

    @classmethod
    def normalize_plan(cls, raw_plan: Optional[str]) -> str:
        """Normalise le nom du plan utilisateur."""
        if not raw_plan:
            return "free"
        p = raw_plan.strip().lower()
        if p in ("pro", "premium"):
            return "premium"
        if p in ("vip",):
            return "vip"
        if p in ("black", "ultra", "black_ultra"):
            return "black"
        return "free"

    @classmethod
    def get_plan_level(cls, plan: str) -> int:
        norm = cls.normalize_plan(plan)
        return cls.PLAN_LEVELS.get(norm, 1)

    @classmethod
    def get_plan_limits(cls, plan: str) -> Dict[str, Any]:
        norm = cls.normalize_plan(plan)
        return cls.PLAN_LIMITS.get(norm, cls.PLAN_LIMITS["free"])

    @classmethod
    def is_model_allowed_for_plan(cls, model_id: str, user_plan: str) -> bool:
        """
        Vérifie si un modèle donné est autorisé pour le niveau du plan de l'utilisateur.
        """
        canonical_model = ModelsCatalog.resolve_model_id(model_id)
        info = ModelsCatalog.get_model_info(canonical_model)
        if not info or not info.get("is_active"):
            return False

        min_required_plan = info.get("min_plan", "free")
        required_level = cls.get_plan_level(min_required_plan)
        user_level = cls.get_plan_level(user_plan)

        return user_level >= required_level

    @classmethod
    def can_select_model_manually(cls, user_plan: str) -> bool:
        """Indique si l'utilisateur a le droit de choisir explicitement son modèle d'IA (VIP & BLACK)."""
        limits = cls.get_plan_limits(user_plan)
        return bool(limits.get("can_select_model", False))

    @classmethod
    def resolve_effective_model(cls, requested_model: Optional[str], user_plan: str) -> str:
        """
        Détermine le modèle effectif pour une requête :
        - Pour FREE et PREMIUM : Modèle optimal assigné par la passerelle SD (gemini-3.6-flash).
        - Pour VIP et BLACK : Modèle demandé s'il est autorisé, sinon modèle par défaut.
        """
        norm_plan = cls.normalize_plan(user_plan)
        can_choose = cls.can_select_model_manually(norm_plan)

        if can_choose and requested_model:
            canonical = ModelsCatalog.resolve_model_id(requested_model)
            if cls.is_model_allowed_for_plan(canonical, norm_plan):
                return canonical
            logger.warning(
                "Modèle %s demandé mais non autorisé pour le plan %s. Rebasculement sur le modèle par défaut.",
                requested_model, norm_plan
            )

        return cls.get_plan_limits(norm_plan).get("default_model", "gemini-3.6-flash")

    @classmethod
    def get_allowed_models_list(cls, user_plan: str) -> List[Dict[str, Any]]:
        """Retourne la liste des modèles actifs utilisables par le plan."""
        norm_plan = cls.normalize_plan(user_plan)
        user_level = cls.get_plan_level(norm_plan)

        allowed = []
        for m in ModelsCatalog.list_active_models():
            req_level = cls.get_plan_level(m.get("min_plan", "free"))
            if user_level >= req_level:
                allowed.append(m)
        return allowed
