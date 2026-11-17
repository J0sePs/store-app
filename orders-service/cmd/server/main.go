// Comando server: servicio HTTP de pedidos.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"orders-service/internal/config"
	"orders-service/internal/handler"
	"orders-service/internal/repository"
)

const (
	listenAddr      = ":8080"
	connectAttempts = 5
	connectDelay    = 2 * time.Second
	shutdownTimeout = 10 * time.Second
)

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))
	if err := run(logger); err != nil {
		logger.Error("El servicio terminó con error", "error", err)
		os.Exit(1)
	}
}

func run(logger *slog.Logger) error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("cargar la configuración: %w", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	logger.Info("Iniciando el servicio de pedidos", "version", cfg.AppVersion)

	pool, err := connect(ctx, cfg.DatabaseURL, logger)
	if err != nil {
		return err
	}
	defer pool.Close()

	repo := repository.New(pool)
	migrateCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	if err := repo.Migrate(migrateCtx); err != nil {
		return err
	}
	logger.Info("Migración aplicada")

	srv := &http.Server{
		Addr:              listenAddr,
		Handler:           handler.New(repo, cfg.AppVersion, logger),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	serverErr := make(chan error, 1)
	go func() {
		logger.Info("Escuchando peticiones", "direccion", listenAddr)
		serverErr <- srv.ListenAndServe()
	}()

	select {
	case err := <-serverErr:
		if !errors.Is(err, http.ErrServerClosed) {
			return fmt.Errorf("servidor HTTP: %w", err)
		}
	case <-ctx.Done():
		logger.Info("Señal de parada recibida; apagando el servicio")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			return fmt.Errorf("apagar el servidor: %w", err)
		}
	}
	logger.Info("Servicio de pedidos detenido")
	return nil
}

// connect abre el pool y reintenta hasta que la base de datos responda.
func connect(ctx context.Context, databaseURL string, logger *slog.Logger) (*pgxpool.Pool, error) {
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, fmt.Errorf("configurar la conexión a la base de datos: %w", err)
	}
	for attempt := 1; attempt <= connectAttempts; attempt++ {
		pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
		err = pool.Ping(pingCtx)
		cancel()
		if err == nil {
			return pool, nil
		}
		logger.Warn("No se pudo conectar a la base de datos", "intento", attempt, "de", connectAttempts, "error", err)
		if attempt == connectAttempts {
			break
		}
		select {
		case <-time.After(connectDelay):
		case <-ctx.Done():
			pool.Close()
			return nil, fmt.Errorf("conexión cancelada: %w", ctx.Err())
		}
	}
	pool.Close()
	return nil, fmt.Errorf("no se pudo conectar a la base de datos tras %d intentos: %w", connectAttempts, err)
}
