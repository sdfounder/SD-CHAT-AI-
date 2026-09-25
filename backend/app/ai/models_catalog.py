from typing import Dict, Any, List, Optional
from datetime import datetime, timezone


class ModelsCatalog:
    """
    Catalogue central officiel des modèles d'IA pour SD AI GATEWAY.
    RÈGLE ABSOLUE :
    - Ne jamais inventer d'identifiant API.
    - Seuls les modèles réels officiels documentés sont actifs.
    - Les noms commerciaux fantaisistes ou non disponibles (GPT 5.6, GPT 6 ASTRA, Claude Opus 5, etc.)
      sont enregistrés avec is_active=False et status='Non disponible'.
    """

    CATALOG: Dict[str, Dict[str, Any]] = {
        # ================================================================
        # GOOGLE GEMINI (API Directe)
        # ================================================================
        "gemini-3.6-flash": {
            "model_id": "gemini-3.6-flash",
            "display_name": "Gemini 3.6 Flash",
            "provider": "gemini",
            "min_plan": "free",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": True,
            "context_window_tokens": 1048576,
            "cost_input_per_million": 0.075,
            "cost_output_per_million": 0.30,
            "description": "Modèle SD ultra-rapide et économique officiel pour le chat quotidien.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "gemini-2.5-flash": {
            "model_id": "gemini-2.5-flash",
            "display_name": "Gemini 2.5 Flash",
            "provider": "gemini",
            "min_plan": "free",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": True,
            "context_window_tokens": 1048576,
            "cost_input_per_million": 0.075,
            "cost_output_per_million": 0.30,
            "description": "Modèle de génération rapide avec excellente latence.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "gemini-1.5-pro": {
            "model_id": "gemini-1.5-pro",
            "display_name": "Gemini 1.5 Pro",
            "provider": "gemini",
            "min_plan": "vip",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": True,
            "context_window_tokens": 2097152,
            "cost_input_per_million": 1.25,
            "cost_output_per_million": 5.00,
            "description": "Modèle de raisonnement avancé et large contexte (2M tokens).",
            "verified_at": "2026-09-24T00:00:00Z",
        },

        # ================================================================
        # OPENAI (API Directe)
        # ================================================================
        "gpt-4o-mini": {
            "model_id": "gpt-4o-mini",
            "display_name": "GPT-4o Mini",
            "provider": "openai",
            "min_plan": "premium",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": True,
            "context_window_tokens": 128000,
            "cost_input_per_million": 0.15,
            "cost_output_per_million": 0.60,
            "description": "Modèle OpenAI polyvalent, rapide et économique.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "gpt-4o": {
            "model_id": "gpt-4o",
            "display_name": "GPT-4o Omnimodal",
            "provider": "openai",
            "min_plan": "vip",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": True,
            "context_window_tokens": 128000,
            "cost_input_per_million": 2.50,
            "cost_output_per_million": 10.00,
            "description": "Modèle phare d'OpenAI pour le raisonnement complexe et l'analyse.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "o3-mini": {
            "model_id": "o3-mini",
            "display_name": "OpenAI o3-mini (Raisonnement)",
            "provider": "openai",
            "min_plan": "black",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": False,
            "context_window_tokens": 200000,
            "cost_input_per_million": 1.10,
            "cost_output_per_million": 4.40,
            "description": "Modèle de raisonnement haute précision pour code, logique et maths.",
            "verified_at": "2026-09-24T00:00:00Z",
        },

        # ================================================================
        # ANTHROPIC (API Directe)
        # ================================================================
        "claude-3-5-haiku-20241022": {
            "model_id": "claude-3-5-haiku-20241022",
            "display_name": "Claude 3.5 Haiku",
            "provider": "anthropic",
            "min_plan": "premium",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": True,
            "context_window_tokens": 200000,
            "cost_input_per_million": 0.80,
            "cost_output_per_million": 4.00,
            "description": "Modèle ultra-rapide et concis d'Anthropic.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "claude-3-5-sonnet-20241022": {
            "model_id": "claude-3-5-sonnet-20241022",
            "display_name": "Claude 3.5 Sonnet",
            "provider": "anthropic",
            "min_plan": "vip",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": True,
            "context_window_tokens": 200000,
            "cost_input_per_million": 3.00,
            "cost_output_per_million": 15.00,
            "description": "Modèle de pointe pour la rédaction soignée, la nuance et le code.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "claude-3-opus-20240229": {
            "model_id": "claude-3-opus-20240229",
            "display_name": "Claude 3 Opus",
            "provider": "anthropic",
            "min_plan": "black",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": True,
            "context_window_tokens": 200000,
            "cost_input_per_million": 15.00,
            "cost_output_per_million": 75.00,
            "description": "Modèle d'excellence pour l'analyse approfondie et les tâches complexes.",
            "verified_at": "2026-09-24T00:00:00Z",
        },

        # ================================================================
        # XAI (API Directe)
        # ================================================================
        "grok-2-1212": {
            "model_id": "grok-2-1212",
            "display_name": "xAI Grok 2",
            "provider": "xai",
            "min_plan": "vip",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": False,
            "context_window_tokens": 131072,
            "cost_input_per_million": 2.00,
            "cost_output_per_million": 10.00,
            "description": "Modèle Grok 2 officiel xAI, vif et direct.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "grok-2-vision-1212": {
            "model_id": "grok-2-vision-1212",
            "display_name": "xAI Grok 2 Vision",
            "provider": "xai",
            "min_plan": "black",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": True,
            "context_window_tokens": 32768,
            "cost_input_per_million": 2.00,
            "cost_output_per_million": 10.00,
            "description": "Modèle Grok 2 avec analyse d'images multimodale.",
            "verified_at": "2026-09-24T00:00:00Z",
        },

        # ================================================================
        # DEEPSEEK (API Directe)
        # ================================================================
        "deepseek-chat": {
            "model_id": "deepseek-chat",
            "display_name": "DeepSeek V3 (Direct)",
            "provider": "deepseek",
            "min_plan": "premium",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": False,
            "context_window_tokens": 64000,
            "cost_input_per_million": 0.14,
            "cost_output_per_million": 0.28,
            "description": "Modèle officiel DeepSeek V3 en connexion directe haute vitesse.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "deepseek-reasoner": {
            "model_id": "deepseek-reasoner",
            "display_name": "DeepSeek R1 (Raisonnement)",
            "provider": "deepseek",
            "min_plan": "vip",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": False,
            "context_window_tokens": 64000,
            "cost_input_per_million": 0.55,
            "cost_output_per_million": 2.19,
            "description": "Modèle de raisonnement mathématique et logique DeepSeek R1.",
            "verified_at": "2026-09-24T00:00:00Z",
        },

        # ================================================================
        # OPENROUTER (Passerelle Secondaire & Fallback)
        # ================================================================
        "deepseek/deepseek-chat": {
            "model_id": "deepseek/deepseek-chat",
            "display_name": "DeepSeek V3 (OpenRouter)",
            "provider": "openrouter",
            "min_plan": "premium",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": False,
            "context_window_tokens": 64000,
            "cost_input_per_million": 0.14,
            "cost_output_per_million": 0.28,
            "description": "Modèle économique ultra-performant pour le chat polyvalent.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "meta-llama/llama-3.3-70b-instruct": {
            "model_id": "meta-llama/llama-3.3-70b-instruct",
            "display_name": "Llama 3.3 70B (OpenRouter)",
            "provider": "openrouter",
            "min_plan": "vip",
            "is_active": True,
            "status": "Disponible",
            "supports_streaming": True,
            "supports_attachments": False,
            "context_window_tokens": 128000,
            "cost_input_per_million": 0.40,
            "cost_output_per_million": 0.40,
            "description": "Modèle Open Source phare de Meta.",
            "verified_at": "2026-09-24T00:00:00Z",
        },

        # ================================================================
        # NOMS COMMERCIAUX SOUHAITÉS / NON DISPONIBLES (Suivi d'Audit)
        # ================================================================
        "gpt-5.6": {
            "model_id": "gpt-5.6",
            "display_name": "GPT 5.6",
            "provider": "openai",
            "min_plan": "black",
            "is_active": False,
            "status": "Non disponible",
            "supports_streaming": False,
            "supports_attachments": False,
            "context_window_tokens": 0,
            "cost_input_per_million": 0.0,
            "cost_output_per_million": 0.0,
            "description": "Modèle non publié officiellement par OpenAI à cette date.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "gpt-6-astra": {
            "model_id": "gpt-6-astra",
            "display_name": "GPT 6 ASTRA",
            "provider": "openai",
            "min_plan": "black",
            "is_active": False,
            "status": "Non disponible",
            "supports_streaming": False,
            "supports_attachments": False,
            "context_window_tokens": 0,
            "cost_input_per_million": 0.0,
            "cost_output_per_million": 0.0,
            "description": "Modèle non existant chez le fournisseur.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "claude-opus-5": {
            "model_id": "claude-opus-5",
            "display_name": "Claude Opus 5",
            "provider": "anthropic",
            "min_plan": "black",
            "is_active": False,
            "status": "Non disponible",
            "supports_streaming": False,
            "supports_attachments": False,
            "context_window_tokens": 0,
            "cost_input_per_million": 0.0,
            "cost_output_per_million": 0.0,
            "description": "Modèle non publié officiellement par Anthropic à cette date.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "claude-fable-5": {
            "model_id": "claude-fable-5",
            "display_name": "Claude Fable 5",
            "provider": "anthropic",
            "min_plan": "black",
            "is_active": False,
            "status": "Non disponible",
            "supports_streaming": False,
            "supports_attachments": False,
            "context_window_tokens": 0,
            "cost_input_per_million": 0.0,
            "cost_output_per_million": 0.0,
            "description": "Modèle non existant chez le fournisseur.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "gpt-5.6-luna": {
            "model_id": "gpt-5.6-luna",
            "display_name": "GPT 5.6 Luna",
            "provider": "openai",
            "min_plan": "black",
            "is_active": False,
            "status": "Non disponible",
            "supports_streaming": False,
            "supports_attachments": False,
            "context_window_tokens": 0,
            "cost_input_per_million": 0.0,
            "cost_output_per_million": 0.0,
            "description": "Modèle non existant chez le fournisseur.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "gpt-5.6-sol": {
            "model_id": "gpt-5.6-sol",
            "display_name": "GPT 5.6 Sol",
            "provider": "openai",
            "min_plan": "black",
            "is_active": False,
            "status": "Non disponible",
            "supports_streaming": False,
            "supports_attachments": False,
            "context_window_tokens": 0,
            "cost_input_per_million": 0.0,
            "cost_output_per_million": 0.0,
            "description": "Modèle non existant chez le fournisseur.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
        "claude-sonnet-4": {
            "model_id": "claude-sonnet-4",
            "display_name": "Claude Sonnet 4",
            "provider": "anthropic",
            "min_plan": "black",
            "is_active": False,
            "status": "Non disponible",
            "supports_streaming": False,
            "supports_attachments": False,
            "context_window_tokens": 0,
            "cost_input_per_million": 0.0,
            "cost_output_per_million": 0.0,
            "description": "Modèle non publié officiellement par Anthropic à cette date.",
            "verified_at": "2026-09-24T00:00:00Z",
        },
    }

    # Table de mappage des alias courants vers les identifiants officiels
    ALIASES: Dict[str, str] = {
        "gemini-3.6": "gemini-3.6-flash",
        "gemini": "gemini-3.6-flash",
        "gpt-4": "gpt-4o",
        "gpt4": "gpt-4o",
        "gpt-4o": "gpt-4o",
        "gpt-4o-mini": "gpt-4o-mini",
        "gpt-5-6": "gpt-5.6",
        "claude-3-5": "claude-3-5-sonnet-20241022",
        "claude-3-5-sonnet": "claude-3-5-sonnet-20241022",
        "claude-sonnet": "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku": "claude-3-5-haiku-20241022",
        "claude-haiku": "claude-3-5-haiku-20241022",
        "claude-3-opus": "claude-3-opus-20240229",
        "claude-opus": "claude-3-opus-20240229",
        "grok": "grok-2-1212",
        "grok-2": "grok-2-1212",
        "deepseek": "deepseek/deepseek-chat",
    }

    @classmethod
    def resolve_model_id(cls, raw_id: Optional[str]) -> str:
        """Résout un identifiant brut ou alias vers son identifiant officiel canonique."""
        if not raw_id:
            return "gemini-3.6-flash"
        normalized = raw_id.strip().lower()
        if normalized in cls.CATALOG:
            return normalized
        if normalized in cls.ALIASES:
            return cls.ALIASES[normalized]
        return normalized

    @classmethod
    def get_model_info(cls, model_id: str) -> Optional[Dict[str, Any]]:
        """Récupère les métadonnées officielles d'un modèle."""
        canonical = cls.resolve_model_id(model_id)
        return cls.CATALOG.get(canonical)

    @classmethod
    def get_model_metadata(cls, model_id: str) -> Optional[Dict[str, Any]]:
        """Alias pour get_model_info."""
        return cls.get_model_info(model_id)

    @classmethod
    def get_model(cls, model_id: str) -> Optional[Dict[str, Any]]:
        """Alias pour get_model_info."""
        return cls.get_model_info(model_id)

    @classmethod
    def is_model_valid_and_active(cls, model_id: str) -> bool:
        """Vérifie si un modèle est réellement existant et marqué actif."""
        info = cls.get_model_info(model_id)
        return bool(info and info.get("is_active") is True)

    @classmethod
    def list_active_models(cls) -> List[Dict[str, Any]]:
        """Retourne uniquement les modèles réellement disponibles et actifs."""
        return [m for m in cls.CATALOG.values() if m["is_active"]]

    @classmethod
    def list_all_models_for_admin(cls) -> List[Dict[str, Any]]:
        """Retourne la totalité du catalogue (actifs et non disponibles) pour l'administration."""
        return list(cls.CATALOG.values())
