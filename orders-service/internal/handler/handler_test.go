package handler

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"orders-service/internal/model"
)

// fakeStore es un almacén en memoria para probar el handler sin base de datos.
type fakeStore struct {
	mu     sync.Mutex
	orders []model.Order
	err    error // si no es nil, todas las operaciones fallan con este error
}

func (f *fakeStore) List(_ context.Context) ([]model.Order, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return nil, f.err
	}
	return append([]model.Order(nil), f.orders...), nil // nil si está vacío
}

func (f *fakeStore) Get(_ context.Context, id int64) (model.Order, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return model.Order{}, f.err
	}
	for _, o := range f.orders {
		if o.ID == id {
			return o, nil
		}
	}
	return model.Order{}, model.ErrNotFound
}

func (f *fakeStore) Create(_ context.Context, in model.CreateOrderInput) (model.Order, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return model.Order{}, f.err
	}
	o := model.Order{
		ID: int64(len(f.orders) + 1), ProductID: in.ProductID, Quantity: in.Quantity,
		Customer: in.Customer, Status: model.StatusPending, CreatedAt: time.Now().UTC(),
	}
	f.orders = append(f.orders, o)
	return o, nil
}

func newServer(store *fakeStore) http.Handler {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return New(store, "1.2.3", logger)
}

func do(t *testing.T, h http.Handler, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func decode[T any](t *testing.T, rec *httptest.ResponseRecorder) T {
	t.Helper()
	var v T
	if err := json.Unmarshal(rec.Body.Bytes(), &v); err != nil {
		t.Fatalf("respuesta no es JSON válido (%q): %v", rec.Body.String(), err)
	}
	return v
}

func seeded() *fakeStore {
	s := &fakeStore{}
	_, _ = s.Create(context.Background(), model.CreateOrderInput{ProductID: 1, Quantity: 2, Customer: "Ana"})
	_, _ = s.Create(context.Background(), model.CreateOrderInput{ProductID: 3, Quantity: 1, Customer: "Luis"})
	return s
}

// --- GET /health ---

func TestHealth(t *testing.T) {
	rec := do(t, newServer(&fakeStore{}), http.MethodGet, "/health", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("código %d", rec.Code)
	}
	got := decode[map[string]string](t, rec)
	if got["status"] != "ok" || got["version"] != "1.2.3" {
		t.Fatalf("respuesta inesperada: %v", got)
	}
}

func TestHealthNoConsultaLaBase(t *testing.T) {
	store := &fakeStore{err: errors.New("base caída")}
	if rec := do(t, newServer(store), http.MethodGet, "/health", ""); rec.Code != http.StatusOK {
		t.Fatalf("health debe responder 200 aunque la base falle, llegó %d", rec.Code)
	}
}

// --- GET /orders ---

func TestListConPedidos(t *testing.T) {
	rec := do(t, newServer(seeded()), http.MethodGet, "/orders", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("código %d", rec.Code)
	}
	orders := decode[[]map[string]any](t, rec)
	if len(orders) != 2 {
		t.Fatalf("se esperaban 2 pedidos, llegaron %d", len(orders))
	}
	for _, campo := range []string{"id", "product_id", "quantity", "customer", "status", "created_at"} {
		if _, ok := orders[0][campo]; !ok {
			t.Errorf("falta el campo %s", campo)
		}
	}
}

func TestListSinPedidosDevuelveArregloVacio(t *testing.T) {
	rec := do(t, newServer(&fakeStore{}), http.MethodGet, "/orders", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("código %d", rec.Code)
	}
	if got := strings.TrimSpace(rec.Body.String()); got != "[]" {
		t.Fatalf("se esperaba [], llegó %s", got)
	}
}

func TestListConBarraFinal(t *testing.T) {
	if rec := do(t, newServer(seeded()), http.MethodGet, "/orders/", ""); rec.Code != http.StatusOK {
		t.Fatalf("código %d", rec.Code)
	}
}

// --- GET /orders/{id} ---

func TestGetExistente(t *testing.T) {
	rec := do(t, newServer(seeded()), http.MethodGet, "/orders/1", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("código %d", rec.Code)
	}
	if o := decode[model.Order](t, rec); o.ID != 1 || o.Customer != "Ana" {
		t.Fatalf("pedido inesperado: %+v", o)
	}
}

func TestGetInexistente(t *testing.T) {
	rec := do(t, newServer(seeded()), http.MethodGet, "/orders/9999", "")
	if rec.Code != http.StatusNotFound {
		t.Fatalf("código %d", rec.Code)
	}
	if got := decode[map[string]string](t, rec); got["error"] != "Pedido no encontrado" {
		t.Fatalf("mensaje inesperado: %v", got)
	}
}

func TestGetIdInvalido(t *testing.T) {
	for _, id := range []string{"abc", "0", "-5", "1.5"} {
		rec := do(t, newServer(seeded()), http.MethodGet, "/orders/"+id, "")
		if rec.Code != http.StatusBadRequest {
			t.Fatalf("id %q: código %d", id, rec.Code)
		}
		if got := decode[map[string]string](t, rec); got["error"] != "Identificador inválido" {
			t.Fatalf("id %q: mensaje inesperado: %v", id, got)
		}
	}
}

// --- POST /orders ---

func TestCreaPedido(t *testing.T) {
	store := &fakeStore{}
	h := newServer(store)
	rec := do(t, h, http.MethodPost, "/orders", `{"product_id": 1, "quantity": 2, "customer": "Ana"}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("código %d: %s", rec.Code, rec.Body.String())
	}
	creado := decode[model.Order](t, rec)
	if creado.ID == 0 || creado.Status != "pending" || creado.CreatedAt.IsZero() {
		t.Fatalf("pedido inesperado: %+v", creado)
	}
	// Un GET posterior devuelve el mismo pedido
	again := decode[model.Order](t, do(t, h, http.MethodGet, "/orders/1", ""))
	if again.ID != creado.ID || again.Customer != "Ana" {
		t.Fatalf("el pedido no coincide: %+v vs %+v", again, creado)
	}
}

func TestStatusDelClienteSeIgnora(t *testing.T) {
	rec := do(t, newServer(&fakeStore{}), http.MethodPost, "/orders",
		`{"product_id": 1, "quantity": 1, "customer": "Ana", "status": "shipped"}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("código %d", rec.Code)
	}
	if o := decode[model.Order](t, rec); o.Status != "pending" {
		t.Fatalf("el status debe ser pending, llegó %q", o.Status)
	}
}

func TestPostInvalidoNoCrea(t *testing.T) {
	casos := map[string]string{
		"cantidad cero":     `{"product_id": 1, "quantity": 0, "customer": "Ana"}`,
		"producto cero":     `{"product_id": 0, "quantity": 1, "customer": "Ana"}`,
		"producto negativo": `{"product_id": -2, "quantity": 1, "customer": "Ana"}`,
		"cliente vacío":     `{"product_id": 1, "quantity": 1, "customer": ""}`,
		"cliente ausente":   `{"product_id": 1, "quantity": 1}`,
		"json mal formado":  `{"product_id": 1,`,
		"cuerpo vacío":      ``,
		"cantidad enorme":   `{"product_id": 1, "quantity": 99999999999, "customer": "Ana"}`,
	}
	for nombre, cuerpo := range casos {
		t.Run(nombre, func(t *testing.T) {
			store := &fakeStore{}
			rec := do(t, newServer(store), http.MethodPost, "/orders", cuerpo)
			if rec.Code != http.StatusBadRequest {
				t.Fatalf("código %d: %s", rec.Code, rec.Body.String())
			}
			if got := decode[map[string]string](t, rec); got["error"] == "" {
				t.Fatalf("falta el mensaje de error: %s", rec.Body.String())
			}
			if len(store.orders) != 0 {
				t.Fatalf("no debía crearse ningún pedido")
			}
		})
	}
}

// --- errores internos y rutas ---

func TestErrorDelRepositorioDevuelve500SinFiltrar(t *testing.T) {
	store := &fakeStore{err: errors.New("password authentication failed for user secreto")}
	h := newServer(store)
	peticiones := []struct{ metodo, ruta, cuerpo string }{
		{http.MethodGet, "/orders", ""},
		{http.MethodGet, "/orders/1", ""},
		{http.MethodPost, "/orders", `{"product_id": 1, "quantity": 1, "customer": "Ana"}`},
	}
	for _, p := range peticiones {
		rec := do(t, h, p.metodo, p.ruta, p.cuerpo)
		if rec.Code != http.StatusInternalServerError {
			t.Fatalf("%s %s: código %d", p.metodo, p.ruta, rec.Code)
		}
		if got := decode[map[string]string](t, rec); got["error"] != "Error interno del servidor" {
			t.Fatalf("mensaje inesperado: %v", got)
		}
		if strings.Contains(rec.Body.String(), "secreto") {
			t.Fatalf("la respuesta filtra detalles internos: %s", rec.Body.String())
		}
	}
}

func TestRutaInexistenteYMetodoNoPermitido(t *testing.T) {
	h := newServer(&fakeStore{})
	if rec := do(t, h, http.MethodGet, "/nada", ""); rec.Code != http.StatusNotFound {
		t.Fatalf("ruta inexistente: código %d", rec.Code)
	}
	if rec := do(t, h, http.MethodDelete, "/orders/1", ""); rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("método no permitido: código %d", rec.Code)
	}
}
