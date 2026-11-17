package config

import (
	"errors"
	"testing"
)

func TestLoadVariablesDefinidas(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://u:p@db:5432/orders")
	t.Setenv("APP_VERSION", "1.2.3")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("no se esperaba error: %v", err)
	}
	if cfg.DatabaseURL != "postgres://u:p@db:5432/orders" || cfg.AppVersion != "1.2.3" {
		t.Fatalf("configuración inesperada: %+v", cfg)
	}
}

func TestLoadFaltaDatabaseURL(t *testing.T) {
	t.Setenv("DATABASE_URL", "")

	_, err := Load()
	if !errors.Is(err, ErrMissingDatabaseURL) {
		t.Fatalf("se esperaba ErrMissingDatabaseURL, llegó: %v", err)
	}
}

func TestLoadVersionPorDefecto(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://x")
	t.Setenv("APP_VERSION", "")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("no se esperaba error: %v", err)
	}
	if cfg.AppVersion != "dev" {
		t.Fatalf("la versión por defecto debe ser dev, llegó %q", cfg.AppVersion)
	}
}
