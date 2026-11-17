"""Motor, sesiones e inicialización de la base de datos."""

import logging
import time
from collections.abc import Callable
from decimal import Decimal

from sqlalchemy import Engine, create_engine, func, select
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session, sessionmaker

from app.db.base import Base
from app.models.product import Product

logger = logging.getLogger("products-service")

# Productos de ejemplo que se siembran solo si la tabla está vacía
SEED_PRODUCTS: list[tuple[str, Decimal, int]] = [
    ("Teclado mecánico", Decimal("45.90"), 25),
    ("Mouse inalámbrico", Decimal("19.99"), 50),
    ("Monitor 24 pulgadas", Decimal("139.00"), 10),
]


def make_engine(database_url: str) -> Engine:
    """Crea el motor de SQLAlchemy a partir de la URL de conexión."""
    return create_engine(database_url, pool_pre_ping=True)


def make_session_factory(engine: Engine) -> sessionmaker[Session]:
    """Crea la fábrica de sesiones asociada al motor."""
    return sessionmaker(bind=engine, expire_on_commit=False)


def seed_products(session: Session) -> int:
    """Inserta los productos de ejemplo si la tabla está vacía; devuelve cuántos insertó."""
    total = session.scalar(select(func.count()).select_from(Product)) or 0
    if total > 0:
        logger.info("La tabla de productos ya tiene %d registros; no se siembra", total)
        return 0
    session.add_all(Product(name=n, price=p, stock=s) for n, p, s in SEED_PRODUCTS)
    session.commit()
    logger.info("Se sembraron %d productos de ejemplo", len(SEED_PRODUCTS))
    return len(SEED_PRODUCTS)


def init_db(
    engine: Engine,
    session_factory: sessionmaker[Session],
    attempts: int = 3,
    delay: float = 2.0,
    sleep: Callable[[float], None] = time.sleep,
) -> None:
    """Crea las tablas y siembra datos; reintenta si la base de datos aún no responde."""
    for attempt in range(1, attempts + 1):
        try:
            Base.metadata.create_all(engine)
            with session_factory() as session:
                seed_products(session)
            return
        except OperationalError:
            logger.warning(
                "No se pudo conectar a la base de datos (intento %d de %d)", attempt, attempts
            )
            if attempt == attempts:
                logger.error("No se pudo conectar a la base de datos tras %d intentos", attempts)
                raise
            sleep(delay)
