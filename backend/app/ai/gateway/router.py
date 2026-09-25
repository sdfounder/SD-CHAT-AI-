import time
import uuid
import logging
from typing import AsyncGenerator, Dict, Any, List, Optional

from app.ai.base_provider import BaseLLMProvider
from app.ai.gemini_provider import GeminiProvider
from app.ai.openai_provider import OpenAIProvider
from app.ai.anthropic_provider import AnthropicProvider
from app.ai.xai_provider import XAIProvider
from app.ai.openrouter_provider import OpenRouterProvider
from app.ai.deepseek_provider import DeepSeekProvider
from app.ai.models_catalog import ModelsCatalog
from app.ai.gateway.circuit_breaker import circuit_breaker
from app.ai.gateway.plan_engine import PlanEngine
from app.core.config import settings
from app.database.connection import db_manager

logger = logging.getLogger(__name__)


class ProviderRouter:
    """
    Routeur intelligent et résilient du SD AI GATEWAY.
    Orchestre la sélection des modèles, le routage des requêtes et le basculement (fallback)
    automatique et sécurisé en respectant scrupuleusement les niveaux de plan utilisateur.
    """

    def __init__(self):
        # Instances réutilisables des adaptateurs
        self._providers: Dict[str, BaseLLMProvider] = {
            "gemini": GeminiProvider(),
            "deepseek": DeepSeekProvider(),
            "openai": OpenAIProvider(),
            "anthropic": AnthropicProvider(),
            "xai": XAIProvider(),
            "openrouter": OpenRouterProvider(),
        }

    def get_provider_instance(self, provider_name: str) -> Optional[BaseLLMProvider]:
        return self._providers.get(provider_name.lower())

    def get_all_provider_statuses(self) -> List[Dict[str, Any]]:
        """Retourne l'état consolidé de tous les fournisseurs pour le dashboard d'administration."""
        statuses = []
        cb_statuses = circuit_breaker.get_all_statuses()
        for name, inst in self._providers.items():
            base_st = inst.get_provider_status()
            cb_st = cb_statuses.get(name, {})
            base_st["circuit_breaker"] = cb_st.get("state", "closed")
            base_st["is_available"] = cb_st.get("is_available", base_st["is_active"])
            base_st["failure_count"] = cb_st.get("failure_count", 0)
            base_st["last_error"] = cb_st.get("last_error")
            statuses.append(base_st)
        return statuses

    def _build_route_candidates(
        self,
        requested_model: Optional[str],
        user_plan: str,
    ) -> List[Dict[str, Any]]:
        """
        Construit la liste ordonnée des candidats d'exécution (modèle + provider).
        Garantit que TOUS les candidats respectent le niveau du plan de l'utilisateur.
        """
        norm_plan = PlanEngine.normalize_plan(user_plan)
        effective_model = PlanEngine.resolve_effective_model(requested_model, norm_plan)
        primary_info = ModelsCatalog.get_model_info(effective_model)
        primary_provider = primary_info.get("provider", "gemini") if primary_info else "gemini"

        candidates = [
            {
                "provider": primary_provider,
                "model": effective_model,
                "is_primary": True,
            }
        ]

        # Déterminer les solutions de secours autorisées pour ce plan
        allowed_models = PlanEngine.get_allowed_models_list(norm_plan)

        # Ordre de secours privilégié : Gemini (socle SD) -> DeepSeek -> OpenAI -> Anthropic -> OpenRouter -> xAI
        fallback_priority = ["gemini", "deepseek", "openai", "anthropic", "openrouter", "xai"]

        for fav_p in fallback_priority:
            if fav_p == primary_provider:
                continue
            # Chercher le modèle le plus adapté autorisé pour ce plan chez ce provider
            matching_models = [m for m in allowed_models if m["provider"] == fav_p and m["is_active"]]
            if matching_models:
                candidates.append({
                    "provider": fav_p,
                    "model": matching_models[0]["model_id"],
                    "is_primary": False,
                })

        return candidates

    async def route_stream(
        self,
        messages: List[Dict[str, str]],
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
        requested_model: Optional[str] = None,
        user_plan: str = "free",
        user_id: Optional[str] = None,
        conversation_id: Optional[str] = None,
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """
        Routage intelligent du streaming SSE avec basculement automatique sans perte de tokens.
        Émet des dictionnaires d'événements pour le chat service :
        - {"type": "metadata", "provider": ..., "model": ..., "fallback_used": ...}
        - {"type": "token", "content": ...}
        - {"type": "done", "prompt_tokens": ..., "completion_tokens": ...}
        """
        request_id = str(uuid.uuid4())
        start_time = time.time()
        ttft_recorded = False
        ttft_ms = 0
        total_tokens_output = 0

        candidates = self._build_route_candidates(requested_model, user_plan)
        last_error = None
        executed_candidate = None
        fallback_used = False

        for idx, cand in enumerate(candidates):
            p_name = cand["provider"]
            m_name = cand["model"]
            is_fallback = (idx > 0)

            # Vérification circuit breaker & credentials
            provider_inst = self.get_provider_instance(p_name)
            if not provider_inst:
                continue

            status_info = provider_inst.get_provider_status()
            if not status_info.get("is_configured"):
                # Provider sans clé API -> on passe immédiatement au suivant
                continue

            if not circuit_breaker.is_available(p_name):
                logger.warning("Provider %s écarté par le circuit breaker.", p_name)
                continue

            # Tentative d'exécution
            yielded_any_token = False
            try:
                if is_fallback:
                    fallback_used = True
                    logger.info("SD AI GATEWAY: Déclenchement fallback vers %s (%s)", p_name, m_name)

                # Émettre l'événement initial de confirmation du modèle
                yield {
                    "type": "init",
                    "request_id": request_id,
                    "provider": p_name,
                    "model": m_name,
                    "fallback_used": is_fallback,
                }

                stream_gen = provider_inst.stream_message(
                    messages=messages,
                    system_instruction=system_instruction,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    model=m_name,
                )

                async for token in stream_gen:
                    if not ttft_recorded:
                        ttft_ms = int((time.time() - start_time) * 1000)
                        ttft_recorded = True
                    yielded_any_token = True
                    total_tokens_output += 1
                    yield {"type": "token", "content": token}

                # Succès complet de génération
                circuit_breaker.record_success(p_name)
                executed_candidate = cand
                break

            except Exception as exc:
                err_category = provider_inst.classify_error(exc)
                logger.warning(
                    "Échec d'exécution sur %s (%s): %s [Catégorie: %s]",
                    p_name, m_name, exc, err_category
                )

                # Si des tokens ont déjà été envoyés au client, on ne peut pas recommencer à zéro
                if yielded_any_token:
                    logger.error("Interruption du flux en cours de route sur %s.", p_name)
                    executed_candidate = cand
                    break

                # Enregistrer l'échec pour le circuit breaker
                circuit_breaker.record_failure(p_name, str(exc)[:200])
                last_error = exc

                # Erreurs non éligibles au fallback (requête invalide, contenu refusé)
                if err_category in ("bad_request", "content_policy"):
                    raise

                # Continuer vers le candidat suivant de la chaîne de secours

        if not executed_candidate and not yielded_any_token:
            total_duration_ms = int((time.time() - start_time) * 1000)
            self._record_metrics_safe(
                conversation_id=conversation_id,
                user_id=user_id,
                user_tier=user_plan,
                provider="none",
                model=requested_model or "unknown",
                prompt_tokens=len(str(messages)) // 4,
                completion_tokens=0,
                latency_ms=total_duration_ms,
                ttft_ms=0,
                status="failed",
                error_message=str(last_error)[:255] if last_error else "Aucun fournisseur disponible",
            )
            raise RuntimeError(f"Échec de tous les fournisseurs SD AI Gateway disponibles. Erreur : {last_error}")

        total_duration_ms = int((time.time() - start_time) * 1000)
        p_tok = len(str(messages)) // 4
        c_tok = total_tokens_output

        yield {
            "type": "done",
            "request_id": request_id,
            "provider": executed_candidate["provider"] if executed_candidate else "gemini",
            "model": executed_candidate["model"] if executed_candidate else "gemini-3.6-flash",
            "fallback_used": fallback_used,
            "prompt_tokens": p_tok,
            "completion_tokens": c_tok,
            "total_tokens": p_tok + c_tok,
            "latency_ms": total_duration_ms,
            "ttft_ms": ttft_ms,
        }

        # Enregistrement asynchrone des métriques
        self._record_metrics_safe(
            conversation_id=conversation_id,
            user_id=user_id,
            user_tier=user_plan,
            provider=executed_candidate["provider"] if executed_candidate else "gemini",
            model=executed_candidate["model"] if executed_candidate else "gemini-3.6-flash",
            prompt_tokens=p_tok,
            completion_tokens=c_tok,
            latency_ms=total_duration_ms,
            ttft_ms=ttft_ms,
            status="success",
            error_message=None,
        )

    def _record_metrics_safe(
        self,
        conversation_id: Optional[str],
        user_id: Optional[str],
        user_tier: Optional[str],
        provider: str,
        model: str,
        prompt_tokens: int,
        completion_tokens: int,
        latency_ms: int,
        ttft_ms: int,
        status: str,
        error_message: Optional[str],
    ):
        """Enregistre de manière résiliente les métriques dans Supabase PostgreSQL."""
        try:
            metric_id = str(uuid.uuid4())
            with db_manager.connect() as conn:
                conn.run(
                    """
                    INSERT INTO public.ai_request_metrics (
                        id, conversation_id, user_id, user_tier, provider, model,
                        prompt_tokens, completion_tokens, total_tokens,
                        latency_ms, ttft_ms, status, error_message, created_at
                    ) VALUES (
                        :id, :cid, :uid, :tier, :prov, :mdl,
                        :ptok, :ctok, :ttok,
                        :lat, :ttft, :st, :err, NOW()
                    )
                    """,
                    id=metric_id,
                    cid=conversation_id,
                    uid=user_id,
                    tier=user_tier or "free",
                    prov=provider,
                    mdl=model,
                    ptok=prompt_tokens,
                    ctok=completion_tokens,
                    ttok=prompt_tokens + completion_tokens,
                    lat=latency_ms,
                    ttft=ttft_ms,
                    st=status,
                    err=error_message,
                )
        except Exception as e:
            logger.debug("Impossible d'enregistrer ai_request_metrics: %s", e)


# Instance globale du routeur
ai_gateway_router = ProviderRouter()
