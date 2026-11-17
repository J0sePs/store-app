"""Modelo de producto."""

from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, Integer, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Product(Base):
    """Producto del catálogo."""

    __tablename__ = "products"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    stock: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    # La fecha la asigna la base de datos, no el cliente
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
