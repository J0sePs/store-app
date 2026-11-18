"""Migraciones sencillas que se aplican al arrancar (sin Alembic).

Base.metadata.create_all crea las tablas que faltan pero no modifica las existentes; por eso las
columnas nuevas se añaden aquí, de forma idempotente, para bases que ya tienen datos.
"""

import logging

from sqlalchemy import Engine, inspect, text

logger = logging.getLogger("products-service")

# PostgreSQL: idempotente y seguro si dos instancias arrancan a la vez. Con un valor por defecto
# constante solo modifica metadatos (no reescribe la tabla); los existentes reciben 'General'
ADD_CATEGORY_POSTGRES = (
    "ALTER TABLE products ADD COLUMN IF NOT EXISTS category VARCHAR(100) NOT NULL DEFAULT 'General'"
)
# SQLite (solo en las pruebas) no admite IF NOT EXISTS en ADD COLUMN: se comprueba la columna antes
ADD_CATEGORY_GENERIC = (
    "ALTER TABLE products ADD COLUMN category VARCHAR(100) NOT NULL DEFAULT 'General'"
)


def ensure_category_column(engine: Engine) -> bool:
    """Añade la columna category a products si falta; devuelve True si la columna no existía."""
    columns = {column["name"] for column in inspect(engine).get_columns("products")}
    missing = "category" not in columns
    with engine.begin() as connection:
        if engine.dialect.name == "postgresql":
            connection.execute(text(ADD_CATEGORY_POSTGRES))
        elif missing:
            connection.execute(text(ADD_CATEGORY_GENERIC))
    if missing:
        logger.info(
            "Migración aplicada: columna category añadida a products (por defecto 'General')"
        )
    else:
        logger.info("Migración de category: la columna ya existe, no hay nada que hacer")
    return missing
