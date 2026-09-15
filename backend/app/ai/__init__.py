from typing import Optional
from app.ai.base_provider import BaseLLMProvider
from app.ai.gemini_provider import GeminiProvider


def get_ai_provider(
    provider_name: Optional[str] = None,
    model: Optional[str] = None,
) -> BaseLLMProvider:
    """
    Factory pour instancier le fournisseur d'IA approprié.
    Par défaut, utilise Google Gemini V1.
    Permet de basculer en un seul endroit vers un futur modèle propriétaire SD.
    """
    provider = provider_name or "gemini"

    if provider == "gemini":
        return GeminiProvider(model=model)
    elif provider == "sd_proprietary":
        # Réservé pour le modèle propriétaire SD futur
        raise NotImplementedError("Le modèle propriétaire SD sera disponible dans une prochaine version.")
    else:
        # Fallback par défaut sur Gemini
        return GeminiProvider(model=model)
