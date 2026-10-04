"""Migração de schema, executada fora do startup da aplicação.

Uso:
    python -m app.migrate

Conecta com as mesmas variáveis da aplicação (``DATABASE_URL`` ou ``DB_*``),
que aqui devem apontar para um usuário com permissão de DDL. Aplica, em ordem,
os arquivos ``.sql`` de ``app/migrations`` ainda não registrados.

Se ``APP_DB_USER`` e ``APP_DB_PASSWORD`` estiverem definidos, cria (ou atualiza)
um usuário de aplicação com permissão apenas de leitura e escrita na tabela,
sem DDL. É esse usuário que a aplicação deve usar em execução.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import psycopg
from psycopg import sql

from app.config import build_conninfo

MIGRATIONS_DIR = Path(__file__).parent / "migrations"


def pending_migrations(applied: set[str]) -> list[Path]:
    return [p for p in sorted(MIGRATIONS_DIR.glob("*.sql")) if p.name not in applied]


def apply_migrations(conn: psycopg.Connection) -> list[str]:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS schema_migrations (
            filename   TEXT PRIMARY KEY,
            applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
        """
    )
    applied = {row[0] for row in conn.execute("SELECT filename FROM schema_migrations")}
    done: list[str] = []
    for path in pending_migrations(applied):
        conn.execute(path.read_text(encoding="utf-8"))
        conn.execute("INSERT INTO schema_migrations (filename) VALUES (%s)", (path.name,))
        done.append(path.name)
    return done


def ensure_app_role(conn: psycopg.Connection, user: str, password: str) -> None:
    role = sql.Identifier(user)
    exists = conn.execute("SELECT 1 FROM pg_roles WHERE rolname = %s", (user,)).fetchone()
    verb = (
        sql.SQL("ALTER ROLE {} LOGIN PASSWORD {}")
        if exists
        else sql.SQL("CREATE ROLE {} LOGIN PASSWORD {}")
    )
    conn.execute(verb.format(role, sql.Literal(password)))
    dbname = conn.info.dbname
    conn.execute(sql.SQL("GRANT CONNECT ON DATABASE {} TO {}").format(sql.Identifier(dbname), role))
    conn.execute(sql.SQL("GRANT USAGE ON SCHEMA public TO {}").format(role))
    conn.execute(sql.SQL("GRANT SELECT, INSERT ON service_events TO {}").format(role))
    conn.execute(
        sql.SQL("GRANT USAGE, SELECT ON SEQUENCE service_events_id_seq TO {}").format(role)
    )


def main() -> int:
    conninfo = build_conninfo(os.environ)
    with psycopg.connect(conninfo) as conn:
        done = apply_migrations(conn)
        app_user = os.environ.get("APP_DB_USER")
        app_password = os.environ.get("APP_DB_PASSWORD")
        if app_user and app_password:
            ensure_app_role(conn, app_user, app_password)
            print(f"usuário de aplicação garantido: {app_user}")
    print("migrações aplicadas: " + (", ".join(done) if done else "nenhuma pendente"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
