-- Tabela de eventos de teste do laboratório.
-- Equivalente ao schema exportado do ambiente de origem.
CREATE TABLE IF NOT EXISTS service_events (
    id         BIGSERIAL PRIMARY KEY,
    event_type TEXT NOT NULL,
    node_name  TEXT NOT NULL,
    details    JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
