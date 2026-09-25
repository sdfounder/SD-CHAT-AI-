import logging
import time
import threading
import urllib.parse
import socket
import ssl
from contextlib import contextmanager
import pg8000.native
from fastapi import HTTPException
from app.core.config import settings

logger = logging.getLogger(__name__)


class DatabaseConnectionManager:
    """Gestionnaire de connexion directe PostgreSQL (Supabase SD-DEV Pooler) avec cache de connexion réutilisable."""

    def __init__(self):
        self._lock = threading.RLock()

        self._conn = None
        self._last_used = 0.0
        self._depth = 0
        self._refresh_config()

    def _refresh_config(self):
        parsed = urllib.parse.urlparse(settings.database_url)
        self._user = urllib.parse.unquote(parsed.username or "postgres.ryvmacsmfvllhgbqbnkb")
        self._password = urllib.parse.unquote(parsed.password or "sekoudiaby224")
        self._host = parsed.hostname or "aws-1-eu-west-1.pooler.supabase.com"
        self._port = parsed.port or 5432
        self._database = parsed.path.lstrip("/") or "postgres"

    def _create_connection(self) -> pg8000.native.Connection:
        """Ouvre une nouvelle connexion vers le pooler PostgreSQL avec SSL et résolution DNS IPv4 directe."""
        self._refresh_config()
        target_host = self._host

        # Forcer la résolution IPv4 explicite pour éliminer tout blocage IPv6 (Errno 93 / timeout 60s)
        try:
            target_host = socket.gethostbyname(self._host)
        except Exception as dns_err:
            logger.debug("Résolution DNS IPv4 fallback sur hostname: %s", dns_err)

        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        last_err = None
        for attempt in range(2):
            try:
                return pg8000.native.Connection(
                    user=self._user,
                    password=self._password,
                    host=target_host,
                    port=self._port,
                    database=self._database,
                    ssl_context=ctx,
                    timeout=30,
                )

            except Exception as e:
                last_err = e
                if attempt == 1:
                    raise
                time.sleep(0.3)
        raise last_err

    def get_connection(self) -> pg8000.native.Connection:
        """Fournit une connexion neuve isolée."""
        return self._create_connection()

    @contextmanager
    def connect(self):
        """Context manager qui réutilise la connexion active avec verrouillage de transaction PgBouncer et robustesse."""
        with self._lock:
            now = time.time()
            # Si la connexion a été inactive plus de 45 secondes, vérifier sa vivacité hors transaction
            if self._conn is not None and self._depth == 0:
                if now - self._last_used > 45:
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
                self._depth = 0

            # Verrouiller le backend Supavisor/PgBouncer via BEGIN au niveau racine pour éviter les collisions de requêtes préparées
            is_root = (self._depth == 0)
            if is_root:
                try:
                    self._conn.run("BEGIN")
                except Exception as b_err:
                    logger.debug("Échec BEGIN initial (%s), réouverture connexion...", b_err)
                    try:
                        self._conn.close()
                    except Exception:
                        pass
                    self._conn = self._create_connection()
                    self._conn.run("BEGIN")

            self._depth += 1
            self._last_used = time.time()

            try:
                yield self._conn
                self._depth -= 1
                if self._depth == 0 and self._conn is not None:
                    try:
                        self._conn.run("COMMIT")
                    except Exception as c_err:
                        logger.warning("Échec COMMIT (%s), reset connexion", c_err)
                        try:
                            self._conn.close()
                        except Exception:
                            pass
                        self._conn = None
            except HTTPException:
                self._depth -= 1
                if self._depth == 0 and self._conn is not None:
                    try:
                        self._conn.run("ROLLBACK")
                    except Exception:
                        pass
                raise
            except Exception as e:
                self._depth -= 1
                logger.warning("Erreur connexion active (%s), rollback et reinitialisation...", e)
                if self._depth == 0 and self._conn is not None:
                    try:
                        self._conn.run("ROLLBACK")
                    except Exception:
                        pass
                    try:
                        self._conn.close()
                    except Exception:
                        pass
                    self._conn = None
                raise


db_manager = DatabaseConnectionManager()
