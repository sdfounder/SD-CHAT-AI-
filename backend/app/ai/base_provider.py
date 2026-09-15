from abc import ABC, abstractmethod
from typing import AsyncGenerator, Dict, Any, List, Optional


class BaseLLMProvider(ABC):
    """
    Interface abstraite pour tous les fournisseurs d'IA de l'écosystème SD.
    Permet de remplacer Google Gemini ultérieurement par un modèle propriétaire SD
    sans modifier une seule ligne du service de chat ou des endpoints.
    """

    @property
    @abstractmethod
    def provider_name(self) -> str:
        """Nom identifiant le fournisseur (ex: 'gemini', 'sd_proprietary')."""
        pass

    @property
    @abstractmethod
    def model_name(self) -> str:
        """Nom du modèle utilisé."""
        pass

    @abstractmethod
    async def generate_stream(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> AsyncGenerator[str, None]:
        """
        Génère une réponse sous forme de flux de jetons (tokens) en temps réel.
        Chaque yield produit un morceau de texte (chunk/token).
        """
        pass

    @abstractmethod
    async def generate(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> str:
        """Génère une réponse textuelle complète synchrone/bloquante."""
        pass
