import time
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)


class ProviderCircuitBreaker:
    """
    Circuit Breaker par fournisseur IA pour protéger la latence et éviter les boucles d'échecs.
    États :
    - 'closed' : Fonctionnement nominal (actif).
    - 'open' : Suspendu temporairement suite à trop d'échecs consécutifs (503, 429, timeout).
    - 'half_open' : Période d'épreuve pour tester si le fournisseur est rétabli.
    """

    def __init__(
        self,
        failure_threshold: int = 3,
        cooling_seconds: float = 60.0,
        recovery_timeout_seconds: Optional[float] = None,
    ):
        self.failure_threshold = failure_threshold
        self.cooling_seconds = recovery_timeout_seconds if recovery_timeout_seconds is not None else cooling_seconds

        # État par provider_name
        self._states: Dict[str, Dict[str, Any]] = {}

    def _get_state(self, provider: str) -> Dict[str, Any]:
        if provider not in self._states:
            self._states[provider] = {
                "state": "closed",
                "failure_count": 0,
                "last_failure_time": 0.0,
                "last_success_time": 0.0,
                "last_error": None,
                "manually_disabled": False,
            }
        return self._states[provider]

    def get_state(self, provider: str) -> str:
        return self._get_state(provider)["state"]

    def is_available(self, provider: str) -> bool:
        s = self._get_state(provider)
        if s["manually_disabled"]:
            return False

        if s["state"] == "closed":
            return True

        now = time.time()
        if s["state"] == "open":
            if now - s["last_failure_time"] > self.cooling_seconds:
                # Transition vers half_open
                s["state"] = "half_open"
                logger.info("Circuit breaker pour %s passe en half_open (tentative de récupération)", provider)
                return True
            return False

        if s["state"] == "half_open":
            return True

        return False

    def record_success(self, provider: str):
        s = self._get_state(provider)
        s["failure_count"] = 0
        s["state"] = "closed"
        s["last_success_time"] = time.time()
        s["last_error"] = None

    def record_failure(self, provider: str, error_message: str):
        s = self._get_state(provider)
        s["failure_count"] += 1
        s["last_failure_time"] = time.time()
        s["last_error"] = error_message

        if s["failure_count"] >= self.failure_threshold:
            s["state"] = "open"
            logger.warning(
                "Circuit breaker OUVERT pour %s (%s échecs consécutifs). Refroidissement: %.0fs",
                provider, s["failure_count"], self.cooling_seconds
            )

    def reset(self, provider: str):
        """Réinitialise l'état du circuit breaker pour un fournisseur."""
        s = self._get_state(provider)
        s["state"] = "closed"
        s["failure_count"] = 0
        s["last_error"] = None

    def set_manual_override(self, provider: str, disabled: bool):
        s = self._get_state(provider)
        s["manually_disabled"] = disabled
        logger.info("Provider %s statut manuel: %s", provider, "DÉSACTIVÉ" if disabled else "ACTIVÉ")

    def get_all_statuses(self) -> Dict[str, Any]:
        return {
            p: {
                "state": s["state"],
                "failure_count": s["failure_count"],
                "is_available": self.is_available(p),
                "manually_disabled": s["manually_disabled"],
                "last_error": s["last_error"],
                "last_success_time": s["last_success_time"],
            }
            for p, s in self._states.items()
        }


# Instance singleton globale
circuit_breaker = ProviderCircuitBreaker()
