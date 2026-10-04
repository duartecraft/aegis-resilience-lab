"""Fixtures de teste.

Os testes de unidade não exigem banco: o pool é substituído por dublês.
Os testes de integração (marcados com ``integration``) só rodam quando
``TEST_DATABASE_URL`` aponta para um PostgreSQL descartável.
"""

from __future__ import annotations

import os
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("DATABASE_URL", "postgresql://test:test@127.0.0.1:1/test")
os.environ.setdefault("APP_NODE", "app-test")

from app import db  # noqa: E402
from app.config import Settings  # noqa: E402
from app.main import create_app  # noqa: E402

TEST_TOKEN = "token-de-teste"


class FakeDatabase:
    def __init__(self) -> None:
        self.available = True
        self.events: list[tuple[str, str, dict]] = []

    def check_database(self) -> bool:
        return self.available

    def insert_event(self, event_type: str, node_name: str, details: dict):
        if not self.available:
            raise db.DatabaseUnavailable("banco indisponível")
        self.events.append((event_type, node_name, details))
        return len(self.events), datetime(2026, 1, 1, tzinfo=timezone.utc)


@pytest.fixture
def fake_db(monkeypatch: pytest.MonkeyPatch) -> FakeDatabase:
    fake = FakeDatabase()
    monkeypatch.setattr(db, "open_pool", lambda *args, **kwargs: None)
    monkeypatch.setattr(db, "close_pool", lambda: None)
    monkeypatch.setattr(db, "check_database", fake.check_database)
    monkeypatch.setattr(db, "insert_event", fake.insert_event)
    return fake


def make_settings(token: str | None = TEST_TOKEN) -> Settings:
    return Settings(
        app_node="app-test",
        app_version="9.9.9",
        database_conninfo="host=127.0.0.1 port=1 dbname=test",
        events_api_token=token,
    )


@pytest.fixture
def client(fake_db: FakeDatabase):
    with TestClient(create_app(make_settings())) as test_client:
        yield test_client


@pytest.fixture
def client_without_token(fake_db: FakeDatabase):
    with TestClient(create_app(make_settings(token=None))) as test_client:
        yield test_client
