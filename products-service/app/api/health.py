"""Endpoint de salud."""

from fastapi import APIRouter

from app.config import get_app_version

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict[str, str]:
    """Estado del servicio; no consulta la base de datos para no afectar las probes."""
    return {"status": "ok", "version": get_app_version()}
