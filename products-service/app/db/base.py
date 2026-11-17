"""Clase base declarativa de SQLAlchemy."""

from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """Base común de todos los modelos."""
