-- Crea la tabla de pedidos si no existe. Es idempotente: no borra datos existentes.
-- product_id es solo una referencia al producto; no hay clave foránea porque la
-- tabla de productos vive en la base de datos de otro servicio.
CREATE TABLE IF NOT EXISTS orders (
    id         BIGSERIAL PRIMARY KEY,
    product_id BIGINT      NOT NULL,
    quantity   INTEGER     NOT NULL CHECK (quantity > 0),
    customer   TEXT        NOT NULL,
    status     TEXT        NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
