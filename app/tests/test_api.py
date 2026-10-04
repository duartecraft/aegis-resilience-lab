from __future__ import annotations

from tests.conftest import TEST_TOKEN


def test_health_does_not_depend_on_database(client, fake_db):
    fake_db.available = False
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "node": "app-test"}


def test_ready_when_database_is_up(client):
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready", "node": "app-test", "database": "connected"}


def test_ready_returns_503_without_leaking_details(client, fake_db):
    fake_db.available = False
    response = client.get("/ready")
    assert response.status_code == 503
    assert response.json()["detail"] == {
        "status": "not_ready",
        "node": "app-test",
        "database": "unavailable",
    }


def test_status_reports_node_version_and_database(client):
    body = client.get("/api/status").json()
    assert body["node"] == "app-test"
    assert body["version"] == "9.9.9"
    assert body["database"] == {"connected": True, "error": None}
    assert body["timestamp"].endswith("+00:00")


def test_status_stays_200_with_generic_error_when_database_is_down(client, fake_db):
    fake_db.available = False
    response = client.get("/api/status")
    assert response.status_code == 200
    assert response.json()["database"] == {"connected": False, "error": "unavailable"}


def test_home_renders_node_and_version(client):
    response = client.get("/")
    assert response.status_code == 200
    assert "Aegis Resilience Lab" in response.text
    assert "app-test" in response.text
    assert "9.9.9" in response.text
    assert "{{" not in response.text


def test_events_requires_token(client, fake_db):
    assert client.post("/api/events").status_code == 401
    assert client.post("/api/events", headers={"X-API-Key": "errado"}).status_code == 401
    assert fake_db.events == []


def test_events_records_with_valid_token(client, fake_db):
    response = client.post("/api/events", headers={"X-API-Key": TEST_TOKEN})
    assert response.status_code == 201
    assert response.json()["id"] == 1
    assert response.json()["node"] == "app-test"
    event_type, node_name, details = fake_db.events[0]
    assert event_type == "platform_check"
    assert node_name == "app-test"
    assert details["source"] == "aegis-resilience-lab"


def test_events_disabled_when_token_is_not_configured(client_without_token, fake_db):
    response = client_without_token.post("/api/events", headers={"X-API-Key": "qualquer"})
    assert response.status_code == 404
    assert fake_db.events == []


def test_events_returns_503_when_database_is_down(client, fake_db):
    fake_db.available = False
    response = client.post("/api/events", headers={"X-API-Key": TEST_TOKEN})
    assert response.status_code == 503
    assert response.json() == {"detail": "banco indisponível"}


def test_request_id_is_propagated(client):
    trace = "Root=1-67891233-abcdef012345678912345678"
    response = client.get("/health", headers={"X-Amzn-Trace-Id": trace})
    assert response.headers["X-Request-ID"] == trace
    assert client.get("/health").headers["X-Request-ID"]
