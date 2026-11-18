"""Pruebas de la API de productos y de /health."""

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Engine

from app.main import create_app


@pytest.fixture()
def client(engine: Engine) -> Iterator[TestClient]:
    """Cliente con la siembra inicial (3 productos)."""
    with TestClient(create_app(engine)) as c:
        yield c


@pytest.fixture()
def empty_client(engine: Engine, monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    """Cliente con la tabla vacía (sin siembra)."""
    monkeypatch.setattr("app.db.session.SEED_PRODUCTS", [])
    with TestClient(create_app(engine)) as c:
        yield c


# --- GET /products ---


def test_lista_con_datos(client: TestClient) -> None:
    resp = client.get("/products")
    assert resp.status_code == 200
    body = resp.json()
    assert [p["id"] for p in body] == [1, 2, 3]
    assert set(body[0]) == {"id", "name", "category", "price", "stock", "created_at"}
    assert [p["category"] for p in body] == ["Periféricos", "Periféricos", "Monitores"]
    assert isinstance(body[0]["price"], float)


def test_lista_vacia(empty_client: TestClient) -> None:
    resp = empty_client.get("/products")
    assert resp.status_code == 200
    assert resp.json() == []


# --- GET /products/{id} ---


def test_producto_existente(client: TestClient) -> None:
    resp = client.get("/products/1")
    assert resp.status_code == 200
    assert resp.json()["id"] == 1


def test_producto_inexistente(client: TestClient) -> None:
    resp = client.get("/products/9999")
    assert resp.status_code == 404
    assert resp.json() == {"detail": "Producto no encontrado"}


def test_id_invalido(client: TestClient) -> None:
    assert client.get("/products/abc").status_code == 422


# --- POST /products ---


def test_crea_producto(client: TestClient) -> None:
    resp = client.post("/products", json={"name": "Teclado", "price": 25.5, "stock": 10})
    assert resp.status_code == 201
    creado = resp.json()
    assert creado["id"] == 4
    assert creado["created_at"]
    assert creado["price"] == 25.5
    assert client.get(f"/products/{creado['id']}").json() == creado


@pytest.mark.parametrize(
    "payload",
    [
        {"name": "X", "price": 0, "stock": 1},
        {"name": "X", "price": -5, "stock": 1},
        {"name": "X", "price": 5, "stock": -1},
        {"price": 5, "stock": 1},
        {"name": "", "price": 5, "stock": 1},
    ],
)
def test_validacion_rechaza_y_no_crea(client: TestClient, payload: dict[str, object]) -> None:
    assert client.post("/products", json=payload).status_code == 422
    assert len(client.get("/products").json()) == 3


# --- category ---


def test_detalle_incluye_categoria(client: TestClient) -> None:
    resp = client.get("/products/3")
    assert resp.status_code == 200
    assert resp.json()["category"] == "Monitores"


def test_alta_sin_categoria_usa_general(client: TestClient) -> None:
    resp = client.post("/products", json={"name": "Cable", "price": 3.5, "stock": 7})
    assert resp.status_code == 201
    assert resp.json()["category"] == "General"
    assert client.get(f"/products/{resp.json()['id']}").json()["category"] == "General"


def test_alta_con_categoria(client: TestClient) -> None:
    payload = {"name": "Silla", "price": 80, "stock": 3, "category": "Muebles"}
    resp = client.post("/products", json=payload)
    assert resp.status_code == 201
    assert resp.json()["category"] == "Muebles"
    assert client.get(f"/products/{resp.json()['id']}").json()["category"] == "Muebles"


def test_categoria_se_recorta(client: TestClient) -> None:
    payload = {"name": "Mesa", "price": 120, "stock": 1, "category": "  Muebles  "}
    assert client.post("/products", json=payload).json()["category"] == "Muebles"


@pytest.mark.parametrize("categoria", ["", "   ", "x" * 101])
def test_categoria_invalida_no_crea(client: TestClient, categoria: str) -> None:
    payload = {"name": "Silla", "price": 80, "stock": 3, "category": categoria}
    assert client.post("/products", json=payload).status_code == 422
    assert len(client.get("/products").json()) == 3


def test_categoria_de_100_caracteres_es_valida(client: TestClient) -> None:
    payload = {"name": "Silla", "price": 80, "stock": 3, "category": "x" * 100}
    assert client.post("/products", json=payload).status_code == 201


# --- GET /health ---


def test_health_con_version(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok", "version": "1.2.3"}


def test_health_sin_version(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("APP_VERSION", raising=False)
    assert client.get("/health").json() == {"status": "ok", "version": "dev"}


def test_health_con_catalogo_vacio(empty_client: TestClient) -> None:
    assert empty_client.get("/health").status_code == 200


def test_arranque_sin_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    from app.config import ConfigError

    monkeypatch.delenv("DATABASE_URL", raising=False)
    with pytest.raises(ConfigError, match="DATABASE_URL"):
        with TestClient(create_app()):
            pass
