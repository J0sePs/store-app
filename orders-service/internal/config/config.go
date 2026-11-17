// Package config lee la configuración del servicio solo desde variables de entorno (12-factor).
package config

import (
	"errors"
	"os"
	"strings"
)

// ErrMissingDatabaseURL indica que falta la variable de entorno DATABASE_URL.
var ErrMissingDatabaseURL = errors.New("falta la variable de entorno DATABASE_URL")

// Config reúne los valores de configuración del servicio.
type Config struct {
	DatabaseURL string
	AppVersion  string
}

// Load lee la configuración del entorno. APP_VERSION vale "dev" si no está definida.
func Load() (Config, error) {
	databaseURL := strings.TrimSpace(os.Getenv("DATABASE_URL"))
	if databaseURL == "" {
		return Config{}, ErrMissingDatabaseURL
	}
	version := strings.TrimSpace(os.Getenv("APP_VERSION"))
	if version == "" {
		version = "dev"
	}
	return Config{DatabaseURL: databaseURL, AppVersion: version}, nil
}
