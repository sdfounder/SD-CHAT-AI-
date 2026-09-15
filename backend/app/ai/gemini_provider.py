import json
import logging
from typing import AsyncGenerator, Dict, Any, List, Optional
import httpx

from app.ai.base_provider import BaseLLMProvider
from app.core.config import settings

logger = logging.getLogger(__name__)


class GeminiProvider(BaseLLMProvider):
    """
    Implémentation concrète de l'IA via l'API Google Gemini REST v1beta.
    Prend en charge le streaming Server-Sent Events (SSE) temps réel
    et l'exécution standard avec le modèle spécifié (gemini-3.6-flash).
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        model: Optional[str] = None,
    ):
        self._api_key = api_key or settings.gemini_api_key
        self._model = model or settings.gemini_model or "gemini-3.6-flash"

    @property
    def provider_name(self) -> str:
        return "gemini"

    @property
    def model_name(self) -> str:
        return self._model

    def _format_gemini_payload(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> Dict[str, Any]:
        """Convertit le format standard en payload Google Gemini API."""
        contents = []
        for m in messages:
            role = "user" if m.get("role") == "user" else "model"
            content = m.get("content", "")
            if content:
                contents.append({
                    "role": role,
                    "parts": [{"text": content}]
                })

        payload: Dict[str, Any] = {
            "contents": contents,
            "generationConfig": {
                "temperature": temperature,
                "maxOutputTokens": max_tokens,
            }
        }

        if system_instruction:
            payload["system_instruction"] = {
                "parts": [{"text": system_instruction}]
            }

        return payload

    async def generate_stream(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> AsyncGenerator[str, None]:
        """Streaming direct des tokens depuis Google Gemini via SSE."""
        if not self._api_key:
            raise ValueError("GEMINI_API_KEY non configurée dans l'environnement.")

        url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/{self._model}:streamGenerateContent"
            f"?alt=sse&key={self._api_key}"
        )
        payload = self._format_gemini_payload(
            messages=messages,
            system_instruction=system_instruction,
            temperature=temperature,
            max_tokens=max_tokens,
        )

        timeout = httpx.Timeout(60.0, connect=10.0)
        async with httpx.AsyncClient(timeout=timeout) as client:
            async with client.stream("POST", url, json=payload) as response:
                if response.status_code != 200:
                    error_body = await response.aread()
                    logger.error("Gemini API Error %s: %s", response.status_code, error_body.decode())
                    raise RuntimeError(f"Gemini API error ({response.status_code}): {error_body.decode()}")

                async for line in response.aiter_lines():
                    if line.startswith("data: "):
                        data_str = line[6:].strip()
                        if not data_str:
                            continue
                        try:
                            event_data = json.loads(data_str)
                            candidates = event_data.get("candidates", [])
                            if candidates:
                                parts = candidates[0].get("content", {}).get("parts", [])
                                for part in parts:
                                    text_chunk = part.get("text", "")
                                    if text_chunk:
                                        yield text_chunk
                        except json.JSONDecodeError:
                            logger.warning("Erreur décodage JSON SSE: %s", line)

    async def generate(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> str:
        """Appel standard (non-streaming) renvoyant la réponse intégrale."""
        if not self._api_key:
            raise ValueError("GEMINI_API_KEY non configurée dans l'environnement.")

        url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/{self._model}:generateContent"
            f"?key={self._api_key}"
        )
        payload = self._format_gemini_payload(
            messages=messages,
            system_instruction=system_instruction,
            temperature=temperature,
            max_tokens=max_tokens,
        )

        timeout = httpx.Timeout(45.0, connect=10.0)
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(url, json=payload)
            if response.status_code != 200:
                raise RuntimeError(f"Gemini API error ({response.status_code}): {response.text}")
            
            data = response.json()
            candidates = data.get("candidates", [])
            if candidates:
                parts = candidates[0].get("content", {}).get("parts", [])
                full_text = "".join(part.get("text", "") for part in parts)
                return full_text
            return ""
