"""Punto de entrada de la aplicación FastAPI."""

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from sqlalchemy import Engine

from app.api import health, products
from app.config import ConfigError, get_settings
from app.db.session import init_db, make_engine, make_session_factory

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("products-service")


def create_app(engine: Engine | None = None) -> FastAPI:
    """Crea la aplicación; en pruebas se inyecta un motor propio."""

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        db_engine = engine
        if db_engine is None:
            try:
                db_engine = make_engine(get_settings().database_url)
            except ConfigError as exc:
                logger.error("%s", exc)
                raise
        app.state.session_factory = make_session_factory(db_engine)
        logger.info("Iniciando el servicio de productos")
        init_db(db_engine, app.state.session_factory)
        yield
        db_engine.dispose()
        logger.info("Servicio de productos detenido")

    app = FastAPI(title="products-service", lifespan=lifespan)
    app.include_router(health.router)
    app.include_router(products.router)
    return app


app = create_app()
