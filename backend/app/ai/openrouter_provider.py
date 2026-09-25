import json
import logging
from typing import AsyncGenerator, Dict, Any, List, Optional
import httpx

from app.ai.base_provider import BaseLLMProvider
from app.ai.models_catalog import ModelsCatalog
from app.core.config import settings

logger = logging.getLogger(__name__)


class OpenRouterProvider(BaseLLMProvider):
    """
    Fournisseur OpenRouter (Passerelle Secondaire et Solution de Secours).
    Supporte deepseek/deepseek-chat, meta-llama/llama-3.3-70b-instruct, mistralai/mistral-large-2411.
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        model: Optional[str] = None,
    ):
        self._api_key = api_key or settings.openrouter_api_key
        self._model = model or "deepseek/deepseek-chat"

    @property
    def provider_name(self) -> str:
        return "openrouter"

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
            raise ValueError("OPENROUTER_API_KEY non configurée.")

        target_model = model or self._model
        canonical = ModelsCatalog.resolve_model_id(target_model)

        url = "https://openrouter.ai/api/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "HTTP-Referer": "https://sd-chat.ai",
            "X-Title": "SD CHAT AI",
            "Content-Type": "application/json",
        }
        payload = {
            "model": canonical,
            "messages": self._format_messages(messages, system_instruction),
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": True,
        }

        timeout = httpx.Timeout(60.0, connect=10.0)
        async with httpx.AsyncClient(timeout=timeout) as client:
            async with client.stream("POST", url, headers=headers, json=payload) as response:
                if response.status_code != 200:
                    err_text = (await response.aread()).decode(errors="replace")
                    raise RuntimeError(f"Erreur OpenRouter {response.status_code}: {err_text[:200]}")

                async for line in response.aiter_lines():
                    if line.startswith("data: "):
                        data_str = line[6:].strip()
                        if data_str == "[DONE]":
                            break
                        if not data_str:
                            continue
                        try:
                            evt = json.loads(data_str)
                            choices = evt.get("choices", [])
                            if choices:
                                delta = choices[0].get("delta", {})
                                content = delta.get("content", "")
                                if content:
                                    yield content
                        except json.JSONDecodeError:
                            continue

    async def send_message(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
        model: Optional[str] = None,
    ) -> Dict[str, Any]:
        if not self._api_key:
            raise ValueError("OPENROUTER_API_KEY non configurée.")

        target_model = model or self._model
        canonical = ModelsCatalog.resolve_model_id(target_model)

        url = "https://openrouter.ai/api/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "HTTP-Referer": "https://sd-chat.ai",
            "X-Title": "SD CHAT AI",
            "Content-Type": "application/json",
        }
        payload = {
            "model": canonical,
            "messages": self._format_messages(messages, system_instruction),
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": False,
        }

        async with httpx.AsyncClient(timeout=httpx.Timeout(30.0, connect=8.0)) as client:
            response = await client.post(url, headers=headers, json=payload)
            if response.status_code != 200:
                err_text = response.text[:200]
                raise RuntimeError(f"Erreur OpenRouter {response.status_code}: {err_text}")

            data = response.json()
            content = data["choices"][0]["message"]["content"]
            usage = data.get("usage", {})
            p_tok = usage.get("prompt_tokens", len(str(messages)) // 4)
            c_tok = usage.get("completion_tokens", len(content) // 4)

            return {
                "content": content,
                "provider": "openrouter",
                "model": canonical,
                "prompt_tokens": p_tok,
                "completion_tokens": c_tok,
                "total_tokens": p_tok + c_tok,
            }

    async def validate_credentials(self) -> bool:
        if not self._api_key:
            return False
        url = "https://openrouter.ai/api/v1/auth/key"
        headers = {"Authorization": f"Bearer {self._api_key}"}
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(6.0)) as client:
                resp = await client.get(url, headers=headers)
                return resp.status_code == 200
        except Exception:
            return False

    def get_provider_status(self) -> Dict[str, Any]:
        is_configured = bool(self._api_key)
        return {
            "provider": "openrouter",
            "is_configured": is_configured,
            "is_active": is_configured,
            "status": "online" if is_configured else "unconfigured",
            "model": self._model,
            "masked_key": f"sk-or-...{self._api_key[-4:]}" if self._api_key and len(self._api_key) > 8 else None,
        }

    def classify_error(self, error: Exception) -> str:
        err_str = str(error).lower()
        if "429" in err_str or "rate limit" in err_str:
            return "rate_limit"
        if any(c in err_str for c in ("500", "502", "503", "504")):
            return "service_unavailable"
        if "timeout" in err_str or "timed out" in err_str:
            return "timeout"
        if "401" in err_str or "403" in err_str:
            return "auth_error"
        return "unknown_error"

    def estimate_usage(self, prompt: str, completion: str) -> Dict[str, Any]:
        p_tok = max(1, len(prompt) // 4)
        c_tok = max(1, len(completion) // 4)
        cost = (p_tok * 0.14 / 1_000_000) + (c_tok * 0.28 / 1_000_000)
        return {
            "prompt_tokens": p_tok,
            "completion_tokens": c_tok,
            "total_tokens": p_tok + c_tok,
            "estimated_cost_usd": round(cost, 6),
        }

    def get_available_models(self) -> List[Dict[str, Any]]:
        return [
            m for m in ModelsCatalog.list_active_models()
            if m["provider"] == "openrouter"
        ]
