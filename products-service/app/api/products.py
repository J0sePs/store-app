"""Rutas del catálogo de productos."""

import logging
from collections.abc import Iterator
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.product import Product
from app.schemas.product import ProductCreate, ProductRead

logger = logging.getLogger("products-service")

router = APIRouter(prefix="/products", tags=["products"])


def get_session(request: Request) -> Iterator[Session]:
    """Entrega una sesión de base de datos por petición."""
    with request.app.state.session_factory() as session:
        yield session


SessionDep = Annotated[Session, Depends(get_session)]


@router.get("", response_model=list[ProductRead])
def list_products(session: SessionDep) -> list[Product]:
    """Lista todos los productos ordenados por id."""
    return list(session.scalars(select(Product).order_by(Product.id)))


@router.get("/{product_id}", response_model=ProductRead)
def get_product(product_id: int, session: SessionDep) -> Product:
    """Devuelve un producto por su id."""
    product = session.get(Product, product_id)
    if product is None:
        logger.info("Producto %d no encontrado", product_id)
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    return product


@router.post("", response_model=ProductRead, status_code=status.HTTP_201_CREATED)
def create_product(payload: ProductCreate, session: SessionDep) -> Product:
    """Crea un producto nuevo."""
    product = Product(name=payload.name, price=payload.price, stock=payload.stock)
    if payload.category is not None:
        product.category = payload.category
    session.add(product)
    session.commit()
    session.refresh(product)
    logger.info("Producto %d creado", product.id)
    return product
