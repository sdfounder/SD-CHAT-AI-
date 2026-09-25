import asyncio
import json
import logging
from typing import AsyncGenerator, Dict, Any, List, Optional
import httpx

from app.ai.base_provider import BaseLLMProvider
from app.ai.models_catalog import ModelsCatalog
from app.core.config import settings

logger = logging.getLogger(__name__)


class GeminiProvider(BaseLLMProvider):
    """
    Fournisseur officiel Google Gemini (REST v1beta SSE).
    Prend en charge le streaming temps réel, la résilience, et les métadonnées de consommation.
    """

    FALLBACK_MODELS = ["gemini-3.6-flash", "gemini-flash-latest", "gemini-2.5-flash"]

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

    def _get_models_to_try(self, override_model: Optional[str] = None) -> List[str]:
        target = override_model or self._model
        models = [target]
        for fb in self.FALLBACK_MODELS:
            if fb not in models:
                models.append(fb)
        return models

    def _format_gemini_payload(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> Dict[str, Any]:
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
                "maxOutputTokens": max_tokens or 2048,
                "thinkingConfig": {
                    "thinkingBudget": 0
                }
            }
        }

        if system_instruction:
            payload["system_instruction"] = {
                "parts": [{"text": system_instruction}]
            }

        return payload

    async def stream_message(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
        model: Optional[str] = None,
    ) -> AsyncGenerator[str, None]:
        if not self._api_key:
            raise ValueError("GEMINI_API_KEY non configurée dans l'environnement.")

        models_to_try = self._get_models_to_try(model)
        payload = self._format_gemini_payload(
            messages=messages,
            system_instruction=system_instruction,
            temperature=temperature,
            max_tokens=max_tokens,
        )
        headers = {
            "Content-Type": "application/json",
            "x-goog-api-key": self._api_key,
        }
        timeout = httpx.Timeout(60.0, connect=10.0)

        yielded_any = False
        last_error_msg = None

        for current_model in models_to_try:
            url = (
                f"https://generativelanguage.googleapis.com/v1beta/models/{current_model}:streamGenerateContent"
                f"?alt=sse"
            )

            max_retries = 2
            model_success = False

            async with httpx.AsyncClient(timeout=timeout) as client:
                for attempt in range(max_retries):
                    response = None
                    try:
                        response = await client.stream("POST", url, headers=headers, json=payload).__aenter__()
                        if response.status_code in (503, 429) and attempt < max_retries - 1:
                            await response.aclose()
                            wait_seconds = (attempt + 1) * 1.5
                            logger.warning(
                                "Gemini API modèle %s surchargé (%s), tentative %s/%s dans %.1fs...",
                                current_model, response.status_code, attempt + 1, max_retries, wait_seconds
                            )
                            await asyncio.sleep(wait_seconds)
                            continue

                        if response.status_code in (429, 404, 503):
                            clean_err = (await response.aread()).decode(errors="replace")[:200]
                            await response.aclose()
                            logger.warning(
                                "Modèle %s indisponible (%s: %s). Bascule vers le modèle suivant...",
                                current_model, response.status_code, clean_err
                            )
                            last_error_msg = f"{response.status_code}: {clean_err}"
                            break

                        if response.status_code != 200:
                            err_content = (await response.aread()).decode(errors="replace")
                            await response.aclose()
                            logger.error("Erreur Gemini %s: %s", response.status_code, err_content[:200])
                            last_error_msg = f"{response.status_code}: {err_content[:200]}"
                            break

                        # Flux SSE valide
                        try:
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
                                                    yielded_any = True
                                                    yield text_chunk
                                    except json.JSONDecodeError:
                                        logger.warning("Erreur décodage JSON SSE: %s", line[:100])
                            model_success = True
                            break
                        except (httpx.ReadError, httpx.RemoteProtocolError) as stream_err:
                            logger.warning("Interruption du flux pour %s: %s", current_model, stream_err)
                            if yielded_any:
                                model_success = True
                                break
                        finally:
                            await response.aclose()

                    except httpx.RequestError as exc:
                        if attempt < max_retries - 1:
                            await asyncio.sleep(1.0)
                            continue
                        logger.warning("Erreur de requête Gemini %s: %s", current_model, exc)
                        last_error_msg = str(exc)

                if model_success or yielded_any:
                    return

        if not yielded_any:
            raise RuntimeError(f"Échec des modèles Gemini configurés. Dernière erreur: {last_error_msg}")

    async def send_message(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
        model: Optional[str] = None,
    ) -> Dict[str, Any]:
        if not self._api_key:
            raise ValueError("GEMINI_API_KEY non configurée.")

        models_to_try = self._get_models_to_try(model)
        payload = self._format_gemini_payload(
            messages=messages,
            system_instruction=system_instruction,
            temperature=temperature,
            max_tokens=max_tokens,
        )
        headers = {
            "Content-Type": "application/json",
            "x-goog-api-key": self._api_key,
        }
        timeout = httpx.Timeout(30.0, connect=8.0)

        for current_model in models_to_try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{current_model}:generateContent"
            async with httpx.AsyncClient(timeout=timeout) as client:
                try:
                    response = await client.post(url, headers=headers, json=payload)
                    if response.status_code == 200:
                        data = response.json()
                        candidates = data.get("candidates", [])
                        text_output = ""
                        if candidates:
                            parts = candidates[0].get("content", {}).get("parts", [])
                            text_output = "".join(p.get("text", "") for p in parts)
                        
                        usage = data.get("usageMetadata", {})
                        prompt_tok = usage.get("promptTokenCount", len(str(messages)) // 4)
                        comp_tok = usage.get("candidatesTokenCount", len(text_output) // 4)

                        return {
                            "content": text_output,
                            "provider": "gemini",
                            "model": current_model,
                            "prompt_tokens": prompt_tok,
                            "completion_tokens": comp_tok,
                            "total_tokens": prompt_tok + comp_tok,
                        }
                    elif response.status_code in (429, 503):
                        logger.warning("Gemini %s saturé (%s), passage modèle suivant...", current_model, response.status_code)
                        continue
                except httpx.RequestError as exc:
                    logger.warning("Erreur réseau Gemini %s: %s", current_model, exc)
                    continue

        raise RuntimeError("Impossible de générer une réponse avec Google Gemini.")

    async def validate_credentials(self) -> bool:
        if not self._api_key:
            return False
        url = f"https://generativelanguage.googleapis.com/v1beta/models?key={self._api_key}"
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(6.0)) as client:
                resp = await client.get(url)
                return resp.status_code == 200
        except Exception:
            return False

    def get_provider_status(self) -> Dict[str, Any]:
        is_configured = bool(self._api_key)
        return {
            "provider": "gemini",
            "is_configured": is_configured,
            "is_active": is_configured,
            "status": "online" if is_configured else "unconfigured",
            "model": self._model,
            "masked_key": f"AQ...{self._api_key[-4:]}" if self._api_key and len(self._api_key) > 8 else None,
        }

    def classify_error(self, error: Exception) -> str:
        err_str = str(error).lower()
        if "429" in err_str or "resource_exhausted" in err_str:
            return "rate_limit"
        if "503" in err_str or "502" in err_str or "500" in err_str:
            return "service_unavailable"
        if "timeout" in err_str or "timed out" in err_str:
            return "timeout"
        if "401" in err_str or "403" in err_str or "api_key_invalid" in err_str:
            return "auth_error"
        if "safety" in err_str or "blocked" in err_str:
            return "content_policy"
        return "unknown_error"

    def estimate_usage(self, prompt: str, completion: str) -> Dict[str, Any]:
        prompt_tokens = max(1, len(prompt) // 4)
        comp_tokens = max(1, len(completion) // 4)
        cost = (prompt_tokens * 0.075 / 1_000_000) + (comp_tokens * 0.30 / 1_000_000)
        return {
            "prompt_tokens": prompt_tokens,
            "completion_tokens": comp_tokens,
            "total_tokens": prompt_tokens + comp_tokens,
            "estimated_cost_usd": round(cost, 6),
        }

    def get_available_models(self) -> List[Dict[str, Any]]:
        return [
            m for m in ModelsCatalog.list_active_models()
            if m["provider"] == "gemini"
        ]
