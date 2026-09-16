import logging
import time
import threading
import urllib.parse
import socket
import ssl
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
        """Ouvre une nouvelle connexion vers le pooler PostgreSQL avec SSL et résolution DNS directe."""
        self._refresh_config()
        target_host = self._host
        try:
            target_host = socket.gethostbyname(self._host)
        except Exception:
            pass

        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        return pg8000.native.Connection(
            user=self._user,
            password=self._password,
            host=target_host,
            port=self._port,
            database=self._database,
            ssl_context=ctx,
            timeout=30,
        )

    def get_connection(self) -> pg8000.native.Connection:
        """Fournit une connexion neuve isolée."""
        return self._create_connection()

    @contextmanager
    def connect(self):
        """Context manager qui réutilise la connexion active avec rafraîchissement préventif et robustesse."""
        with self._lock:
            now = time.time()
            # Si la connexion a plus de 40 secondes d'inactivité, rafraîchir pour éviter les timeouts côté serveur Supabase
            if self._conn is not None and (now - self._last_used > 40):
                try:
                    self._conn.close()
                except Exception:
                    pass
                self._conn = None

            if self._conn is not None:
                try:
                    self._conn.run("SELECT 1")
                except Exception:
                    try:
                        self._conn.close()
                    except Exception:
                        pass
                    self._conn = None

            if self._conn is None:
                self._conn = self._create_connection()

            try:
                self._last_used = time.time()
                yield self._conn
            except Exception as e:
                logger.warning("Erreur connexion active (%s), reinitialisation...", e)
                try:
                    self._conn.close()
                except Exception:
                    pass
                self._conn = None
                raise


db_manager = DatabaseConnectionManager()
