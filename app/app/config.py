"""Configuração da aplicação, lida exclusivamente de variáveis de ambiente."""

from __future__ import annotations

import os
import socket
from collections.abc import Mapping
from dataclasses import dataclass

from psycopg.conninfo import make_conninfo

DEFAULT_VERSION = "1.1.0"
CONNECT_TIMEOUT_SECONDS = 3


class ConfigurationError(RuntimeError):
    """Configuração obrigatória ausente ou inválida."""


@dataclass(frozen=True)
class Settings:
    app_node: str
    app_version: str
    database_conninfo: str
    events_api_token: str | None


def build_conninfo(env: Mapping[str, str]) -> str:
    """Monta a string de conexão.

    Aceita ``DATABASE_URL`` (compatível com a versão 1.0.0) ou os campos
    separados ``DB_HOST``, ``DB_PORT``, ``DB_NAME``, ``DB_USER`` e
    ``DB_PASSWORD``, que é o formato entregue por gerenciadores de segredos.
    """
    url = env.get("DATABASE_URL", "").strip()
    if url:
        return make_conninfo(url, connect_timeout=CONNECT_TIMEOUT_SECONDS)

    required = ("DB_HOST", "DB_NAME", "DB_USER", "DB_PASSWORD")
    missing = [name for name in required if not env.get(name)]
    if missing:
        raise ConfigurationError("Defina DATABASE_URL ou as variáveis: " + ", ".join(missing))

    params: dict[str, str | int] = {
        "host": env["DB_HOST"],
        "port": env.get("DB_PORT", "5432"),
        "dbname": env["DB_NAME"],
        "user": env["DB_USER"],
        "password": env["DB_PASSWORD"],
        "sslmode": env.get("DB_SSLMODE", "prefer"),
        "connect_timeout": CONNECT_TIMEOUT_SECONDS,
    }
    if env.get("DB_SSLROOTCERT"):
        params["sslrootcert"] = env["DB_SSLROOTCERT"]
    return make_conninfo(**params)


def load_settings(env: Mapping[str, str] | None = None) -> Settings:
    env = os.environ if env is None else env
    return Settings(
        app_node=env.get("APP_NODE") or socket.gethostname(),
        app_version=env.get("APP_VERSION") or DEFAULT_VERSION,
        database_conninfo=build_conninfo(env),
        events_api_token=env.get("EVENTS_API_TOKEN") or None,
    )
