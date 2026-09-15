import logging
import time
import threading
import urllib.parse
from contextlib import contextmanager
import pg8000.native
from app.core.config import settings

logger = logging.getLogger(__name__)


class DatabaseConnectionManager:
    """Gestionnaire de connexion directe PostgreSQL (Supabase SD-DEV Pooler) avec cache de connexion réutilisable."""

    def __init__(self):
        self._lock = threading.Lock()
        self._conn = None
        self._last_used = 0.0
        self._refresh_config()

    def _refresh_config(self):
        parsed = urllib.parse.urlparse(settings.database_url)
        self._user = urllib.parse.unquote(parsed.username or "postgres.ryvmacsmfvllhgbqbnkb")
        self._password = urllib.parse.unquote(parsed.password or "sekoudiaby224")
        self._host = parsed.hostname or "aws-1-eu-west-1.pooler.supabase.com"
        self._port = parsed.port or 5432
        self._database = parsed.path.lstrip("/") or "postgres"

    def _create_connection(self) -> pg8000.native.Connection:
        """Ouvre une nouvelle connexion vers le pooler PostgreSQL."""
        self._refresh_config()
        return pg8000.native.Connection(
            user=self._user,
            password=self._password,
            host=self._host,
            port=self._port,
            database=self._database,
            timeout=15,
        )

    def get_connection(self) -> pg8000.native.Connection:
        """Fournit une connexion neuve isolée."""
        return self._create_connection()

    @contextmanager
    def connect(self):
        """Context manager qui réutilise la connexion active pour un temps de réponse instantané (<300ms au lieu de ~9s)."""
        with self._lock:
            now = time.time()
            if self._conn is None or (now - self._last_used > 60):
                if self._conn:
                    try:
                        self._conn.close()
                    except Exception:
                        pass
                self._conn = self._create_connection()

            try:
                self._last_used = time.time()
                yield self._conn
            except Exception as e:
                logger.warning("Erreur connexion active (%s), reconnexion...", e)
                try:
                    self._conn.close()
                except Exception:
                    pass
                self._conn = self._create_connection()
                self._last_used = time.time()
                yield self._conn


db_manager = DatabaseConnectionManager()
