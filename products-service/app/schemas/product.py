"""Esquemas Pydantic de productos."""

from datetime import datetime
from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, PlainSerializer, field_validator

# El precio se guarda como decimal pero se entrega como número JSON
PriceOut = Annotated[Decimal, PlainSerializer(float, return_type=float, when_used="json")]


class ProductCreate(BaseModel):
    """Cuerpo de POST /products."""

    name: str = Field(min_length=1, max_length=200)
    price: Decimal = Field(gt=0, max_digits=10, decimal_places=2)
    stock: int = Field(ge=0)
    # Opcional: si se omite, la base de datos asigna "General"
    category: str | None = None

    @field_validator("category")
    @classmethod
    def validate_category(cls, value: str | None) -> str | None:
        """Recorta la categoría y exige entre 1 y 100 caracteres si se envía."""
        if value is None:
            return None
        value = value.strip()
        if not 1 <= len(value) <= 100:
            raise ValueError("La categoría debe tener entre 1 y 100 caracteres")
        return value


class ProductRead(BaseModel):
    """Producto devuelto por la API."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    category: str
    price: PriceOut
    stock: int
    created_at: datetime
