"""Pruebas de la migración de la columna category sobre una base creada por la versión anterior."""

from decimal import Decimal

from sqlalchemy import Engine, func, inspect, select, text
from sqlalchemy.orm import Session, sessionmaker

from app.db.migrations import ensure_category_column
from app.db.session import init_db
from app.models.product import Product

# DDL de la v1 (sin category), tal como lo creó create_all en AWS
DDL_V1 = """
CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(200) NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    stock INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
)
"""


def crear_base_v1(engine: Engine) -> None:
    """Crea la tabla sin category y le inserta 3 productos con datos reconocibles."""
    with engine.begin() as connection:
        connection.execute(text(DDL_V1))
        for nombre, precio, stock in [
            ("Teclado", 45.9, 25),
            ("Mouse", 19.99, 50),
            ("Monitor", 139, 10),
        ]:
            connection.execute(
                text("INSERT INTO products (name, price, stock) VALUES (:n, :p, :s)"),
                {"n": nombre, "p": precio, "s": stock},
            )


def columnas(engine: Engine) -> set[str]:
    return {c["name"] for c in inspect(engine).get_columns("products")}


def test_la_base_v1_no_tiene_category(engine: Engine) -> None:
    crear_base_v1(engine)
    assert "category" not in columnas(engine)


def test_migra_una_base_con_datos(engine: Engine, session_factory: sessionmaker[Session]) -> None:
    crear_base_v1(engine)
    init_db(engine, session_factory)

    assert "category" in columnas(engine)
    with session_factory() as session:
        productos = list(session.scalars(select(Product).order_by(Product.id)))
    # No se siembra de nuevo (la tabla ya tenía productos) y los datos se conservan
    assert [p.name for p in productos] == ["Teclado", "Mouse", "Monitor"]
    assert [p.stock for p in productos] == [25, 50, 10]
    assert productos[0].price == Decimal("45.90")
    assert all(p.created_at is not None for p in productos)
    # Los productos existentes reciben el valor por defecto
    assert {p.category for p in productos} == {"General"}


def test_ensure_category_column_devuelve_si_migro(engine: Engine) -> None:
    crear_base_v1(engine)
    assert ensure_category_column(engine) is True
    assert ensure_category_column(engine) is False


def test_migracion_idempotente(engine: Engine, session_factory: sessionmaker[Session]) -> None:
    crear_base_v1(engine)
    init_db(engine, session_factory)
    with session_factory() as session:
        session.add(Product(name="Silla", category="Muebles", price=Decimal("80"), stock=3))
        session.commit()

    init_db(engine, session_factory)  # segundo arranque sobre la base ya migrada

    with session_factory() as session:
        total = session.scalar(select(func.count()).select_from(Product))
        categorias = list(session.scalars(select(Product.category).order_by(Product.id)))
    assert total == 4
    assert categorias == ["General", "General", "General", "Muebles"]


def test_producto_creado_sin_categoria_recibe_general(
    engine: Engine, session_factory: sessionmaker[Session]
) -> None:
    """Simula la versión anterior: inserta sin la columna category y la base completa el valor."""
    crear_base_v1(engine)
    init_db(engine, session_factory)
    with engine.begin() as connection:
        connection.execute(text("INSERT INTO products (name, price, stock) VALUES ('Viejo', 1, 1)"))
    with session_factory() as session:
        assert session.scalar(select(Product.category).where(Product.name == "Viejo")) == "General"


def test_base_nueva_ya_trae_la_columna(
    engine: Engine, session_factory: sessionmaker[Session]
) -> None:
    init_db(engine, session_factory)
    assert "category" in columnas(engine)
    assert ensure_category_column(engine) is False
