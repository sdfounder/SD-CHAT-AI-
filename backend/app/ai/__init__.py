from typing import Optional
from app.ai.base_provider import BaseLLMProvider
from app.ai.gemini_provider import GeminiProvider
from app.ai.openai_provider import OpenAIProvider
from app.ai.anthropic_provider import AnthropicProvider
from app.ai.xai_provider import XAIProvider
from app.ai.openrouter_provider import OpenRouterProvider
from app.ai.deepseek_provider import DeepSeekProvider
from app.ai.models_catalog import ModelsCatalog


def get_ai_provider(
    provider_name: Optional[str] = None,
    model: Optional[str] = None,
) -> BaseLLMProvider:
    """
    Factory pour instancier le fournisseur d'IA approprié dans le SD AI GATEWAY.
    """
    p_name = (provider_name or "").strip().lower()

    # Si aucun provider n'est explicité, déterminer depuis le catalogue de modèles
    if not p_name and model:
        info = ModelsCatalog.get_model_info(model)
        if info:
            p_name = info.get("provider", "gemini")

    if not p_name or p_name == "gemini":
        return GeminiProvider(model=model)
    elif p_name == "openai":
        return OpenAIProvider(model=model)
    elif p_name == "anthropic":
        return AnthropicProvider(model=model)
    elif p_name == "xai":
        return XAIProvider(model=model)
    elif p_name == "deepseek":
        return DeepSeekProvider(model=model)
    elif p_name == "openrouter":
        return OpenRouterProvider(model=model)
    elif p_name == "sd_proprietary":
        raise NotImplementedError("Le modèle propriétaire souverain SD sera connecté en V2.")
    else:
        # Fallback automatique sur Gemini si provider inconnu
        return GeminiProvider(model=model)


__all__ = [
    "BaseLLMProvider",
    "GeminiProvider",
    "OpenAIProvider",
    "AnthropicProvider",
    "XAIProvider",
    "DeepSeekProvider",
    "OpenRouterProvider",
    "ModelsCatalog",
    "get_ai_provider",
]
