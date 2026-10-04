"""API do Aegis Resilience Lab.

Endpoints:
- GET  /            página de demonstração
- GET  /health      liveness: não depende do banco
- GET  /ready       readiness: exige conectividade com o banco
- GET  /api/status  nó, versão, horário e estado do banco
- POST /api/events  registra um evento de teste (exige token)
"""

from __future__ import annotations

import hmac
import html
import logging
import time
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import HTMLResponse

from app import db
from app.config import Settings, load_settings
from app.logging_config import configure_logging

INDEX_TEMPLATE = (Path(__file__).parent / "templates" / "index.html").read_text(encoding="utf-8")
EVENT_SOURCE = "aegis-resilience-lab"

access_logger = logging.getLogger("aegis.access")


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or load_settings()
    configure_logging(settings.app_node, settings.app_version)

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        db.open_pool(settings.database_conninfo)
        yield
        db.close_pool()

    app = FastAPI(title="Aegis Resilience Lab", version=settings.app_version, lifespan=lifespan)

    @app.middleware("http")
    async def access_log(request: Request, call_next):
        # O load balancer gerenciado injeta X-Amzn-Trace-Id; fora dele, gera-se um id.
        request_id = (
            request.headers.get("x-amzn-trace-id")
            or request.headers.get("x-request-id")
            or uuid.uuid4().hex
        )
        started = time.perf_counter()
        status_code = 500
        try:
            response = await call_next(request)
            status_code = response.status_code
            response.headers["X-Request-ID"] = request_id
            return response
        finally:
            access_logger.info(
                "request",
                extra={
                    "method": request.method,
                    "path": request.url.path,
                    "status": status_code,
                    "duration_ms": round((time.perf_counter() - started) * 1000, 2),
                    "request_id": request_id,
                },
            )

    @app.get("/", response_class=HTMLResponse)
    def home() -> str:
        now = datetime.now(timezone.utc).strftime("%d/%m/%Y %H:%M:%S UTC")
        return (
            INDEX_TEMPLATE.replace("{{NODE}}", html.escape(settings.app_node))
            .replace("{{VERSION}}", html.escape(settings.app_version))
            .replace("{{NOW}}", now)
        )

    @app.get("/health")
    def health() -> dict:
        return {"status": "ok", "node": settings.app_node}

    @app.get("/ready")
    def ready() -> dict:
        if not db.check_database():
            raise HTTPException(
                status_code=503,
                detail={
                    "status": "not_ready",
                    "node": settings.app_node,
                    "database": "unavailable",
                },
            )
        return {"status": "ready", "node": settings.app_node, "database": "connected"}

    @app.get("/api/status")
    def status() -> dict:
        connected = db.check_database()
        return {
            "node": settings.app_node,
            "version": settings.app_version,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "database": {"connected": connected, "error": None if connected else "unavailable"},
        }

    @app.post("/api/events", status_code=201)
    def create_event(x_api_key: str | None = Header(default=None)) -> dict:
        if settings.events_api_token is None:
            # Sem token configurado, o endpoint de escrita fica desabilitado.
            raise HTTPException(status_code=404, detail="Not Found")
        if x_api_key is None or not hmac.compare_digest(
            x_api_key.encode(), settings.events_api_token.encode()
        ):
            raise HTTPException(status_code=401, detail="token ausente ou inválido")

        details = {
            "source": EVENT_SOURCE,
            "node": settings.app_node,
            "recorded_at": datetime.now(timezone.utc).isoformat(),
        }
        try:
            event_id, created_at = db.insert_event("platform_check", settings.app_node, details)
        except db.DatabaseUnavailable:
            raise HTTPException(status_code=503, detail="banco indisponível") from None
        return {
            "id": event_id,
            "node": settings.app_node,
            "created_at": created_at.astimezone(timezone.utc).isoformat(),
        }

    return app


app = create_app()
