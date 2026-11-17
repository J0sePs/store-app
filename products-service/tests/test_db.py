"""Pruebas de modelo, siembra y arranque de la base de datos."""

from decimal import Decimal

import pytest
from sqlalchemy import Engine, func, select
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session, sessionmaker

from app.db.base import Base
from app.db.session import init_db
from app.models.product import Product


def test_guarda_un_producto(engine: Engine, session_factory: sessionmaker[Session]) -> None:
    Base.metadata.create_all(engine)
    with session_factory() as session:
        session.add(Product(name="Cable", price=Decimal("3.50"), stock=7))
        session.commit()
        producto = session.scalars(select(Product)).one()
        assert producto.id == 1
        assert producto.price == Decimal("3.50")
        assert producto.created_at is not None


def test_primer_arranque_siembra_tres(
    engine: Engine, session_factory: sessionmaker[Session]
) -> None:
    init_db(engine, session_factory)
    with session_factory() as session:
        assert session.scalar(select(func.count()).select_from(Product)) == 3


def test_reinicio_no_duplica(engine: Engine, session_factory: sessionmaker[Session]) -> None:
    init_db(engine, session_factory)
    init_db(engine, session_factory)
    with session_factory() as session:
        assert session.scalar(select(func.count()).select_from(Product)) == 3


def test_reintenta_y_falla_tras_los_intentos(
    engine: Engine, session_factory: sessionmaker[Session], monkeypatch: pytest.MonkeyPatch
) -> None:
    llamadas: list[float] = []

    def siempre_falla(*args: object, **kwargs: object) -> None:
        raise OperationalError("SELECT 1", {}, Exception("sin conexión"))

    monkeypatch.setattr(Base.metadata, "create_all", siempre_falla)
    with pytest.raises(OperationalError):
        init_db(engine, session_factory, attempts=3, delay=2.0, sleep=llamadas.append)
    assert llamadas == [2.0, 2.0]
