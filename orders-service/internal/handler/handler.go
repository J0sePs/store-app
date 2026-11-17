// Package handler expone la API HTTP de pedidos con chi.
package handler

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"orders-service/internal/model"
)

// maxBodyBytes limita el tamaño del cuerpo de las peticiones.
const maxBodyBytes = 1 << 20

// OrderStore es lo que el handler necesita de la capa de persistencia.
type OrderStore interface {
	List(ctx context.Context) ([]model.Order, error)
	Get(ctx context.Context, id int64) (model.Order, error)
	Create(ctx context.Context, in model.CreateOrderInput) (model.Order, error)
}

type handler struct {
	store   OrderStore
	version string
	logger  *slog.Logger
}

// New construye el enrutador con todas las rutas del servicio.
func New(store OrderStore, version string, logger *slog.Logger) http.Handler {
	h := &handler{store: store, version: version, logger: logger}

	r := chi.NewRouter()
	r.NotFound(func(w http.ResponseWriter, _ *http.Request) {
		writeError(w, http.StatusNotFound, "Ruta no encontrada")
	})
	r.MethodNotAllowed(func(w http.ResponseWriter, _ *http.Request) {
		writeError(w, http.StatusMethodNotAllowed, "Método no permitido")
	})

	r.Get("/health", h.health)
	r.Route("/orders", func(r chi.Router) {
		r.Get("/", h.listOrders)
		r.Post("/", h.createOrder)
		r.Get("/{id}", h.getOrder)
	})
	// Se aceptan también las rutas sin barra final
	r.Get("/orders", h.listOrders)
	r.Post("/orders", h.createOrder)
	return r
}

// health informa el estado sin consultar la base de datos, para no afectar las probes.
func (h *handler) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "version": h.version})
}

func (h *handler) listOrders(w http.ResponseWriter, r *http.Request) {
	orders, err := h.store.List(r.Context())
	if err != nil {
		h.internalError(w, "listar pedidos", err)
		return
	}
	if orders == nil {
		orders = []model.Order{}
	}
	writeJSON(w, http.StatusOK, orders)
}

func (h *handler) getOrder(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "Identificador inválido")
		return
	}
	order, err := h.store.Get(r.Context(), id)
	if errors.Is(err, model.ErrNotFound) {
		writeError(w, http.StatusNotFound, "Pedido no encontrado")
		return
	}
	if err != nil {
		h.internalError(w, "consultar el pedido", err)
		return
	}
	writeJSON(w, http.StatusOK, order)
}

func (h *handler) createOrder(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxBodyBytes)

	// Los campos desconocidos (p. ej. status) se ignoran: el estado lo fija el servicio
	var in model.CreateOrderInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "El cuerpo de la petición no es un JSON válido")
		return
	}
	in.Normalize()
	if err := in.Validate(); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	order, err := h.store.Create(r.Context(), in)
	if err != nil {
		h.internalError(w, "crear el pedido", err)
		return
	}
	h.logger.Info("pedido creado", "id", order.ID)
	writeJSON(w, http.StatusCreated, order)
}

// internalError registra el detalle y devuelve al cliente un mensaje genérico.
func (h *handler) internalError(w http.ResponseWriter, accion string, err error) {
	h.logger.Error("error interno", "accion", accion, "error", err)
	writeError(w, http.StatusInternalServerError, "Error interno del servidor")
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}
