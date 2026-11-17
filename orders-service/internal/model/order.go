// Package model define las entidades del servicio de pedidos.
package model

import (
	"errors"
	"strings"
	"time"
)

// StatusPending es el estado inicial de todo pedido nuevo.
const StatusPending = "pending"

// Order es un pedido. ProductID es solo una referencia: este servicio nunca
// consulta a products-service ni a su base de datos.
type Order struct {
	ID        int64     `json:"id"`
	ProductID int64     `json:"product_id"`
	Quantity  int32     `json:"quantity"`
	Customer  string    `json:"customer"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

// CreateOrderInput es el cuerpo de POST /orders. No incluye status ni created_at:
// los asigna el servicio.
type CreateOrderInput struct {
	ProductID int64  `json:"product_id"`
	Quantity  int32  `json:"quantity"`
	Customer  string `json:"customer"`
}

// ErrNotFound indica que el pedido solicitado no existe.
var ErrNotFound = errors.New("pedido no encontrado")

// ErrValidation envuelve los errores de validación de la entrada.
var ErrValidation = errors.New("datos de pedido inválidos")

// Normalize quita los espacios sobrantes del cliente.
func (i *CreateOrderInput) Normalize() {
	i.Customer = strings.TrimSpace(i.Customer)
}

// Validate comprueba las reglas de entrada. El error devuelto envuelve ErrValidation
// y su texto está en español para devolverlo tal cual al cliente.
func (i CreateOrderInput) Validate() error {
	switch {
	case i.ProductID <= 0:
		return validationError("product_id debe ser mayor que 0")
	case i.Quantity <= 0:
		return validationError("quantity debe ser mayor que 0")
	case strings.TrimSpace(i.Customer) == "":
		return validationError("customer no puede estar vacío")
	}
	return nil
}

type validationErr struct{ msg string }

func (e validationErr) Error() string { return e.msg }
func (e validationErr) Unwrap() error { return ErrValidation }

func validationError(msg string) error { return validationErr{msg: msg} }
