"""Configuración del servicio, leída solo desde variables de entorno (12-factor)."""

import os
from dataclasses import dataclass


class ConfigError(RuntimeError):
    """Se lanza cuando falta una variable de entorno obligatoria."""


@dataclass(frozen=True)
class Settings:
    """Valores de configuración del servicio."""

    database_url: str


def get_settings() -> Settings:
    """Lee la configuración del entorno; falla con un mensaje en español si falta algo."""
    database_url = os.environ.get("DATABASE_URL", "").strip()
    if not database_url:
        raise ConfigError("Falta la variable de entorno DATABASE_URL")
    return Settings(database_url=database_url)


def get_app_version() -> str:
    """Devuelve la versión de la aplicación (APP_VERSION) o 'dev' si no está definida."""
    return os.environ.get("APP_VERSION", "").strip() or "dev"
