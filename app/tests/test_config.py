from __future__ import annotations

import pytest
from psycopg.conninfo import conninfo_to_dict

from app.config import ConfigurationError, build_conninfo, load_settings


def test_database_url_takes_precedence():
    info = conninfo_to_dict(
        build_conninfo(
            {"DATABASE_URL": "postgresql://u:p@db.example.com:5433/aegis", "DB_HOST": "x"}
        )
    )
    assert info["host"] == "db.example.com"
    assert info["port"] == "5433"
    assert info["connect_timeout"] == "3"


def test_separate_fields_build_conninfo_with_tls_options():
    info = conninfo_to_dict(
        build_conninfo(
            {
                "DB_HOST": "db.example.com",
                "DB_NAME": "aegis",
                "DB_USER": "aegis_app",
                "DB_PASSWORD": "s3nha com espaço e 'aspas'",
                "DB_SSLMODE": "verify-full",
                "DB_SSLROOTCERT": "/etc/ssl/certs/rds-ca.pem",
            }
        )
    )
    assert info["host"] == "db.example.com"
    assert info["port"] == "5432"
    assert info["password"] == "s3nha com espaço e 'aspas'"
    assert info["sslmode"] == "verify-full"
    assert info["sslrootcert"] == "/etc/ssl/certs/rds-ca.pem"


def test_missing_configuration_names_the_missing_variables():
    with pytest.raises(ConfigurationError) as excinfo:
        build_conninfo({"DB_HOST": "db.example.com"})
    message = str(excinfo.value)
    assert "DB_NAME" in message and "DB_USER" in message and "DB_PASSWORD" in message


def test_settings_defaults_and_optional_token():
    settings = load_settings({"DATABASE_URL": "postgresql://u:p@h/d"})
    assert settings.app_version == "1.1.0"
    assert settings.app_node
    assert settings.events_api_token is None
    with_token = load_settings({"DATABASE_URL": "postgresql://u:p@h/d", "EVENTS_API_TOKEN": "abc"})
    assert with_token.events_api_token == "abc"
