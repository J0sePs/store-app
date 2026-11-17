"""Esquemas Pydantic de productos."""

from datetime import datetime
from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, PlainSerializer

# El precio se guarda como decimal pero se entrega como número JSON
PriceOut = Annotated[Decimal, PlainSerializer(float, return_type=float, when_used="json")]


class ProductCreate(BaseModel):
    """Cuerpo de POST /products."""

    name: str = Field(min_length=1, max_length=200)
    price: Decimal = Field(gt=0, max_digits=10, decimal_places=2)
    stock: int = Field(ge=0)


class ProductRead(BaseModel):
    """Producto devuelto por la API."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    price: PriceOut
    stock: int
    created_at: datetime
