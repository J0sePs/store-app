"""Fixtures compartidas: base de datos SQLite en memoria, sin dependencias externas."""

from collections.abc import Iterator

import pytest
from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.session import make_session_factory


@pytest.fixture()
def engine() -> Iterator[Engine]:
    """Motor SQLite en memoria compartido entre conexiones."""
    eng = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    yield eng
    eng.dispose()


@pytest.fixture()
def session_factory(engine: Engine) -> sessionmaker[Session]:
    """Fábrica de sesiones sobre el motor de pruebas."""
    return make_session_factory(engine)
