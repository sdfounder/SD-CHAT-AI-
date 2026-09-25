import logging
from abc import ABC, abstractmethod
from typing import AsyncGenerator, Dict, Any, List, Optional

logger = logging.getLogger(__name__)


class BaseLLMProvider(ABC):
    """
    Interface abstraite normalisée pour tous les fournisseurs d'IA du SD AI GATEWAY :
    - Google Gemini
    - OpenAI
    - Anthropic
    - xAI
    - OpenRouter (secours / passerelle alternative)
    """

    @property
    @abstractmethod
    def provider_name(self) -> str:
        """Nom identifiant unique du fournisseur (ex: 'gemini', 'openai', 'anthropic', 'xai', 'openrouter')."""
        pass

    @property
    @abstractmethod
    def model_name(self) -> str:
        """Nom du modèle principal configuré pour cette instance."""
        pass

    async def stream_message(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
        model: Optional[str] = None,
    ) -> AsyncGenerator[str, None]:
        """Délègue vers generate_stream si la sous-classe l'a implémenté."""
        async for chunk in self.generate_stream(
            messages=messages,
            system_instruction=system_instruction,
            temperature=temperature,
            max_tokens=max_tokens,
        ):
            yield chunk

    async def send_message(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
        model: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Délègue vers generate si la sous-classe l'a implémenté."""
        content = await self.generate(
            messages=messages,
            system_instruction=system_instruction,
            temperature=temperature,
            max_tokens=max_tokens,
        )
        total_tok = len(content.split())
        return {
            "content": content,
            "provider": self.provider_name,
            "model": model or self.model_name,
            "prompt_tokens": len(str(messages)) // 4,
            "completion_tokens": total_tok,
            "total_tokens": (len(str(messages)) // 4) + total_tok,
        }

    async def validate_credentials(self) -> bool:
        """Vérifie la validité réelle des identifiants (clé API) auprès de l'API distante."""
        return True

    def get_provider_status(self) -> Dict[str, Any]:
        """Retourne l'état courant du fournisseur."""
        return {
            "provider": self.provider_name,
            "is_configured": True,
            "is_active": True,
        }

    def classify_error(self, error: Exception) -> str:
        """Catégorise l'erreur."""
        return "unknown"

    def estimate_usage(self, prompt: str, completion: str) -> Dict[str, Any]:
        """Estime le nombre de tokens et le coût indicatif."""
        p_tok = len(prompt.split())
        c_tok = len(completion.split())
        return {
            "prompt_tokens": p_tok,
            "completion_tokens": c_tok,
            "total_tokens": p_tok + c_tok,
            "estimated_cost_usd": 0.0,
        }

    def get_available_models(self) -> List[Dict[str, Any]]:
        """Liste les modèles supportés par défaut."""
        return [{"id": self.model_name, "name": self.model_name}]


    # ====================================================================
    # RÉTROCOMPATIBILITÉ AVEC LE CODE EXISTANT (V1)
    # ====================================================================
    async def generate_stream(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> AsyncGenerator[str, None]:
        """Délègue vers stream_message pour préserver 100% du code existant."""
        async for chunk in self.stream_message(
            messages=messages,
            system_instruction=system_instruction,
            temperature=temperature,
            max_tokens=max_tokens,
        ):
            yield chunk

    async def generate(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> str:
        """Délègue vers send_message pour préserver 100% du code existant."""
        res = await self.send_message(
            messages=messages,
            system_instruction=system_instruction,
            temperature=temperature,
            max_tokens=max_tokens,
        )
        return res.get("content", "")
