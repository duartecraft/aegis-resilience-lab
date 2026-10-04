"""Acesso ao PostgreSQL por meio de um pool de conexões.

O pool é aberto sem esperar pelo banco: a aplicação sobe e responde a
``/health`` mesmo com o PostgreSQL indisponível, e ``/ready`` reflete o estado
real da dependência.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from psycopg.types.json import Jsonb
from psycopg_pool import ConnectionPool

logger = logging.getLogger("aegis.db")

POOL_TIMEOUT_SECONDS = 3.0

_pool: ConnectionPool | None = None


class DatabaseUnavailable(RuntimeError):
    """O banco não respondeu. Os detalhes ficam apenas no log interno."""


def open_pool(conninfo: str, *, min_size: int = 1, max_size: int = 5) -> None:
    global _pool
    if _pool is not None:
        return
    _pool = ConnectionPool(
        conninfo,
        min_size=min_size,
        max_size=max_size,
        timeout=POOL_TIMEOUT_SECONDS,
        check=ConnectionPool.check_connection,
        open=False,
        name="aegis",
    )
    _pool.open(wait=False)


def close_pool() -> None:
    global _pool
    if _pool is not None:
        _pool.close()
        _pool = None


def _require_pool() -> ConnectionPool:
    if _pool is None:
        raise DatabaseUnavailable("pool de conexões não inicializado")
    return _pool


def check_database() -> bool:
    """Retorna True se o banco responde a uma consulta trivial."""
    try:
        with _require_pool().connection() as conn:
            conn.execute("SELECT 1")
        return True
    except Exception:
        logger.exception("falha na verificação do banco")
        return False


def insert_event(event_type: str, node_name: str, details: dict[str, Any]) -> tuple[int, datetime]:
    try:
        with _require_pool().connection() as conn:
            row = conn.execute(
                """
                INSERT INTO service_events (event_type, node_name, details)
                VALUES (%s, %s, %s)
                RETURNING id, created_at
                """,
                (event_type, node_name, Jsonb(details)),
            ).fetchone()
    except Exception as exc:
        logger.exception("falha ao registrar evento")
        raise DatabaseUnavailable("banco indisponível") from exc
    if row is None:
        raise DatabaseUnavailable("inserção não retornou registro")
    return row[0], row[1]
