package model

import (
	"errors"
	"testing"
)

func TestValidate(t *testing.T) {
	casos := []struct {
		nombre  string
		entrada CreateOrderInput
		mensaje string // vacío = válido
	}{
		{"válida", CreateOrderInput{ProductID: 1, Quantity: 2, Customer: "Ana"}, ""},
		{"producto cero", CreateOrderInput{ProductID: 0, Quantity: 2, Customer: "Ana"}, "product_id debe ser mayor que 0"},
		{"producto negativo", CreateOrderInput{ProductID: -3, Quantity: 2, Customer: "Ana"}, "product_id debe ser mayor que 0"},
		{"cantidad cero", CreateOrderInput{ProductID: 1, Quantity: 0, Customer: "Ana"}, "quantity debe ser mayor que 0"},
		{"cantidad negativa", CreateOrderInput{ProductID: 1, Quantity: -1, Customer: "Ana"}, "quantity debe ser mayor que 0"},
		{"cliente vacío", CreateOrderInput{ProductID: 1, Quantity: 1, Customer: ""}, "customer no puede estar vacío"},
		{"cliente con espacios", CreateOrderInput{ProductID: 1, Quantity: 1, Customer: "   "}, "customer no puede estar vacío"},
	}
	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			err := c.entrada.Validate()
			if c.mensaje == "" {
				if err != nil {
					t.Fatalf("no se esperaba error: %v", err)
				}
				return
			}
			if err == nil || err.Error() != c.mensaje {
				t.Fatalf("se esperaba %q, llegó %v", c.mensaje, err)
			}
			if !errors.Is(err, ErrValidation) {
				t.Fatalf("el error debe envolver ErrValidation")
			}
		})
	}
}

func TestNormalizeRecortaCliente(t *testing.T) {
	in := CreateOrderInput{ProductID: 1, Quantity: 1, Customer: "  Ana  "}
	in.Normalize()
	if in.Customer != "Ana" {
		t.Fatalf("se esperaba Ana, llegó %q", in.Customer)
	}
}
