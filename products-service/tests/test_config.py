"""Pruebas de configuración."""

import pytest

from app.config import ConfigError, get_app_version, get_settings


def test_lee_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://u:p@db:5432/products")
    assert get_settings().database_url == "postgresql+psycopg://u:p@db:5432/products"


def test_falta_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("DATABASE_URL", raising=False)
    with pytest.raises(ConfigError, match="DATABASE_URL"):
        get_settings()


def test_version_definida(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    assert get_app_version() == "1.2.3"


def test_version_por_defecto(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("APP_VERSION", raising=False)
    assert get_app_version() == "dev"
