"""Testes de integração contra um PostgreSQL real e descartável.

Rodam apenas quando ``TEST_DATABASE_URL`` está definido, por exemplo no CI,
que sobe um contêiner de PostgreSQL 16 como serviço.
"""

from __future__ import annotations

import os

import psycopg
import pytest

from app import db
from app.migrate import apply_migrations, ensure_app_role

TEST_DATABASE_URL = os.environ.get("TEST_DATABASE_URL")

pytestmark = [
    pytest.mark.integration,
    pytest.mark.skipif(not TEST_DATABASE_URL, reason="TEST_DATABASE_URL não definido"),
]


@pytest.fixture
def migrated_database():
    with psycopg.connect(TEST_DATABASE_URL) as conn:
        apply_migrations(conn)
    yield TEST_DATABASE_URL
    db.close_pool()


def test_migrations_are_idempotent(migrated_database):
    with psycopg.connect(migrated_database) as conn:
        assert apply_migrations(conn) == []
        columns = [
            row[0]
            for row in conn.execute(
                "SELECT column_name FROM information_schema.columns "
                "WHERE table_name = 'service_events' ORDER BY ordinal_position"
            )
        ]
    assert columns == ["id", "event_type", "node_name", "details", "created_at"]


def test_pool_checks_and_inserts(migrated_database):
    db.open_pool(migrated_database)
    assert db.check_database() is True
    event_id, created_at = db.insert_event("platform_check", "app-test", {"source": "test"})
    assert event_id >= 1
    assert created_at.tzinfo is not None


def test_app_role_can_write_but_cannot_change_schema(migrated_database):
    with psycopg.connect(migrated_database) as conn:
        ensure_app_role(conn, "aegis_app_test", "senha-de-teste")
        ensure_app_role(conn, "aegis_app_test", "senha-de-teste")  # idempotente
        conn.execute("SET ROLE aegis_app_test")
        conn.execute(
            "INSERT INTO service_events (event_type, node_name) "
            "VALUES ('platform_check', 'app-test')"
        )
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            conn.execute("DROP TABLE service_events")


def test_check_database_is_false_when_unreachable():
    db.close_pool()
    db.open_pool("host=127.0.0.1 port=1 dbname=none connect_timeout=1")
    try:
        assert db.check_database() is False
    finally:
        db.close_pool()
