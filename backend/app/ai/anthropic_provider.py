import json
import logging
from typing import AsyncGenerator, Dict, Any, List, Optional
import httpx

from app.ai.base_provider import BaseLLMProvider
from app.ai.models_catalog import ModelsCatalog
from app.core.config import settings

logger = logging.getLogger(__name__)


class AnthropicProvider(BaseLLMProvider):
    """
    Fournisseur officiel Anthropic (API Directe Messages v1).
    Supporte claude-3-5-sonnet, claude-3-5-haiku, claude-3-opus avec streaming SSE d'événements content_block_delta.
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        model: Optional[str] = None,
    ):
        self._api_key = api_key or settings.anthropic_api_key
        self._model = model or "claude-3-5-haiku-20241022"

    @property
    def provider_name(self) -> str:
        return "anthropic"

    @property
    def model_name(self) -> str:
        return self._model

    def _format_messages(
        self,
        messages: List[Dict[str, str]],
    ) -> List[Dict[str, str]]:
        formatted = []
        for m in messages:
            role = m.get("role", "user")
            if role not in ("user", "assistant"):
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
            raise ValueError("ANTHROPIC_API_KEY non configurée.")

        target_model = model or self._model
        canonical = ModelsCatalog.resolve_model_id(target_model)

        url = "https://api.anthropic.com/v1/messages"
        headers = {
            "x-api-key": self._api_key,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
        }
        payload: Dict[str, Any] = {
            "model": canonical,
            "messages": self._format_messages(messages),
            "max_tokens": max_tokens,
            "temperature": temperature,
            "stream": True,
        }
        if system_instruction:
            payload["system"] = system_instruction

        timeout = httpx.Timeout(60.0, connect=10.0)
        async with httpx.AsyncClient(timeout=timeout) as client:
            async with client.stream("POST", url, headers=headers, json=payload) as response:
                if response.status_code != 200:
                    err_text = (await response.aread()).decode(errors="replace")
                    raise RuntimeError(f"Erreur Anthropic {response.status_code}: {err_text[:200]}")

                async for line in response.aiter_lines():
                    if line.startswith("data: "):
                        data_str = line[6:].strip()
                        if not data_str:
                            continue
                        try:
                            evt = json.loads(data_str)
                            evt_type = evt.get("type")
                            if evt_type == "content_block_delta":
                                delta = evt.get("delta", {})
                                if delta.get("type") == "text_delta":
                                    yield delta.get("text", "")
                            elif evt_type == "message_stop":
                                break
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
            raise ValueError("ANTHROPIC_API_KEY non configurée.")

        target_model = model or self._model
        canonical = ModelsCatalog.resolve_model_id(target_model)

        url = "https://api.anthropic.com/v1/messages"
        headers = {
            "x-api-key": self._api_key,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
        }
        payload: Dict[str, Any] = {
            "model": canonical,
            "messages": self._format_messages(messages),
            "max_tokens": max_tokens,
            "temperature": temperature,
            "stream": False,
        }
        if system_instruction:
            payload["system"] = system_instruction

        async with httpx.AsyncClient(timeout=httpx.Timeout(30.0, connect=8.0)) as client:
            response = await client.post(url, headers=headers, json=payload)
            if response.status_code != 200:
                err_text = response.text[:200]
                raise RuntimeError(f"Erreur Anthropic {response.status_code}: {err_text}")

            data = response.json()
            blocks = data.get("content", [])
            text_out = "".join(b.get("text", "") for b in blocks if b.get("type") == "text")
            usage = data.get("usage", {})
            p_tok = usage.get("input_tokens", len(str(messages)) // 4)
            c_tok = usage.get("output_tokens", len(text_out) // 4)

            return {
                "content": text_out,
                "provider": "anthropic",
                "model": canonical,
                "prompt_tokens": p_tok,
                "completion_tokens": c_tok,
                "total_tokens": p_tok + c_tok,
            }

    async def validate_credentials(self) -> bool:
        if not self._api_key:
            return False
        # Test minimal 1 token sur haiku
        url = "https://api.anthropic.com/v1/messages"
        headers = {
            "x-api-key": self._api_key,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
        }
        payload = {
            "model": "claude-3-5-haiku-20241022",
            "messages": [{"role": "user", "content": "ping"}],
            "max_tokens": 1,
        }
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(6.0)) as client:
                resp = await client.post(url, headers=headers, json=payload)
                return resp.status_code in (200, 400)
        except Exception:
            return False

    def get_provider_status(self) -> Dict[str, Any]:
        is_configured = bool(self._api_key)
        return {
            "provider": "anthropic",
            "is_configured": is_configured,
            "is_active": is_configured,
            "status": "online" if is_configured else "unconfigured",
            "model": self._model,
            "masked_key": f"sk-ant-...{self._api_key[-4:]}" if self._api_key and len(self._api_key) > 8 else None,
        }

    def classify_error(self, error: Exception) -> str:
        err_str = str(error).lower()
        if "429" in err_str or "rate_limit" in err_str:
            return "rate_limit"
        if "overloaded" in err_str or any(c in err_str for c in ("500", "502", "503", "529")):
            return "service_unavailable"
        if "timeout" in err_str or "timed out" in err_str:
            return "timeout"
        if "401" in err_str or "authentication_error" in err_str:
            return "auth_error"
        if "permission_error" in err_str:
            return "auth_error"
        return "unknown_error"

    def estimate_usage(self, prompt: str, completion: str) -> Dict[str, Any]:
        p_tok = max(1, len(prompt) // 4)
        c_tok = max(1, len(completion) // 4)
        info = ModelsCatalog.get_model_info(self._model) or {}
        in_cost = info.get("cost_input_per_million", 0.80)
        out_cost = info.get("cost_output_per_million", 4.00)
        cost = (p_tok * in_cost / 1_000_000) + (c_tok * out_cost / 1_000_000)
        return {
            "prompt_tokens": p_tok,
            "completion_tokens": c_tok,
            "total_tokens": p_tok + c_tok,
            "estimated_cost_usd": round(cost, 6),
        }

    def get_available_models(self) -> List[Dict[str, Any]]:
        return [
            m for m in ModelsCatalog.list_active_models()
            if m["provider"] == "anthropic"
        ]
