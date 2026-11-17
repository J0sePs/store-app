// Package repository implementa el acceso a la base de datos de pedidos con pgx.
package repository

import (
	"context"
	_ "embed"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"orders-service/internal/model"
)

//go:embed migrations/001_create_orders.sql
var createOrdersSQL string

const orderColumns = "id, product_id, quantity, customer, status, created_at"

// OrderRepository guarda y consulta pedidos en PostgreSQL.
type OrderRepository struct {
	pool *pgxpool.Pool
}

// New crea el repositorio sobre un pool de conexiones ya abierto.
func New(pool *pgxpool.Pool) *OrderRepository {
	return &OrderRepository{pool: pool}
}

// Migrate crea la tabla de pedidos si no existe.
func (r *OrderRepository) Migrate(ctx context.Context) error {
	if _, err := r.pool.Exec(ctx, createOrdersSQL); err != nil {
		return fmt.Errorf("ejecutar la migración de pedidos: %w", err)
	}
	return nil
}

// List devuelve todos los pedidos ordenados por id. Sin pedidos devuelve un slice vacío.
func (r *OrderRepository) List(ctx context.Context) ([]model.Order, error) {
	rows, err := r.pool.Query(ctx, "SELECT "+orderColumns+" FROM orders ORDER BY id")
	if err != nil {
		return nil, fmt.Errorf("listar pedidos: %w", err)
	}
	orders, err := pgx.CollectRows(rows, pgx.RowToStructByPos[model.Order])
	if err != nil {
		return nil, fmt.Errorf("leer pedidos: %w", err)
	}
	if orders == nil {
		orders = []model.Order{}
	}
	return orders, nil
}

// Get devuelve un pedido por id o model.ErrNotFound si no existe.
func (r *OrderRepository) Get(ctx context.Context, id int64) (model.Order, error) {
	rows, err := r.pool.Query(ctx, "SELECT "+orderColumns+" FROM orders WHERE id = $1", id)
	if err != nil {
		return model.Order{}, fmt.Errorf("consultar el pedido %d: %w", id, err)
	}
	order, err := pgx.CollectOneRow(rows, pgx.RowToStructByPos[model.Order])
	if errors.Is(err, pgx.ErrNoRows) {
		return model.Order{}, model.ErrNotFound
	}
	if err != nil {
		return model.Order{}, fmt.Errorf("leer el pedido %d: %w", id, err)
	}
	return order, nil
}

// Create inserta un pedido nuevo con estado pending y devuelve el registro creado.
func (r *OrderRepository) Create(ctx context.Context, in model.CreateOrderInput) (model.Order, error) {
	rows, err := r.pool.Query(ctx,
		"INSERT INTO orders (product_id, quantity, customer, status) VALUES ($1, $2, $3, $4) RETURNING "+orderColumns,
		in.ProductID, in.Quantity, in.Customer, model.StatusPending)
	if err != nil {
		return model.Order{}, fmt.Errorf("crear el pedido: %w", err)
	}
	order, err := pgx.CollectOneRow(rows, pgx.RowToStructByPos[model.Order])
	if err != nil {
		return model.Order{}, fmt.Errorf("leer el pedido creado: %w", err)
	}
	return order, nil
}
