import json
import logging
from typing import AsyncGenerator, Dict, Any, List, Optional
import httpx

from app.ai.base_provider import BaseLLMProvider
from app.ai.models_catalog import ModelsCatalog
from app.core.config import settings

logger = logging.getLogger(__name__)


class DeepSeekProvider(BaseLLMProvider):
    """
    Fournisseur officiel DeepSeek (API Directe v1).
    Supporte deepseek-chat (DeepSeek V3) et deepseek-reasoner (DeepSeek R1).
    Compatible protocole OpenAI avec streaming SSE ultra-rapide.
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        model: Optional[str] = None,
    ):
        self._api_key = api_key or settings.deepseek_api_key
        self._model = model or "deepseek-chat"

    @property
    def provider_name(self) -> str:
        return "deepseek"

    @property
    def model_name(self) -> str:
        return self._model

    def _format_messages(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
    ) -> List[Dict[str, str]]:
        formatted = []
        if system_instruction:
            formatted.append({"role": "system", "content": system_instruction})
        for m in messages:
            role = m.get("role", "user")
            if role not in ("system", "user", "assistant"):
                role = "user"
            formatted.append({"role": role, "content": m.get("content", "")})
        return formatted

    async def stream_message(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
        model: Optional[str] = None,
    ) -> AsyncGenerator[str, None]:
        if not self._api_key:
            raise ValueError("DEEPSEEK_API_KEY non configurée.")

        active_model = model or self._model
        payload = {
            "model": active_model,
            "messages": self._format_messages(messages, system_instruction),
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": True,
        }

        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
        }

        async with httpx.AsyncClient(timeout=60.0) as client:
            async with client.stream(
                "POST",
                "https://api.deepseek.com/chat/completions",
                headers=headers,
                json=payload,
            ) as response:
                if response.status_code != 200:
                    error_text = await response.aread()
                    logger.error(f"[DeepSeek] Erreur HTTP {response.status_code}: {error_text.decode('utf-8', errors='ignore')}")
                    raise RuntimeError(f"Erreur API DeepSeek ({response.status_code}): {error_text.decode('utf-8', errors='ignore')[:200]}")

                async for line in response.aiter_lines():
                    if not line:
                        continue
                    if line.startswith("data: "):
                        data_str = line[6:].strip()
                        if data_str == "[DONE]":
                            break
                        try:
                            chunk = json.loads(data_str)
                            choices = chunk.get("choices", [])
                            if choices:
                                delta = choices[0].get("delta", {})
                                text = delta.get("content", "")
                                if text:
                                    yield text
                        except json.JSONDecodeError:
                            continue

    async def complete_message(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
        model: Optional[str] = None,
    ) -> str:
        if not self._api_key:
            raise ValueError("DEEPSEEK_API_KEY non configurée.")

        active_model = model or self._model
        payload = {
            "model": active_model,
            "messages": self._format_messages(messages, system_instruction),
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": False,
        }

        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                "https://api.deepseek.com/chat/completions",
                headers=headers,
                json=payload,
            )
            if response.status_code != 200:
                raise RuntimeError(f"Erreur DeepSeek ({response.status_code}): {response.text[:200]}")
            data = response.json()
            return data["choices"][0]["message"]["content"]

    def get_provider_status(self) -> Dict[str, Any]:
        info = ModelsCatalog.get_model_info(self._model) or {}
        return {
            "provider": "deepseek",
            "display_name": "DeepSeek API (Directe)",
            "model": self._model,
            "is_active": bool(self._api_key),
            "supports_streaming": True,
            "supports_attachments": False,
            "status": "Opérationnel" if self._api_key else "Clé API manquante",
            "context_window_tokens": info.get("context_window_tokens", 64000),
            "cost_input_per_million": info.get("cost_input_per_million", 0.14),
            "cost_output_per_million": info.get("cost_output_per_million", 0.28),
        }
