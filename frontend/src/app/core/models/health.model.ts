/** Respuesta de GET /health de cada servicio. */
export interface HealthResponse {
  status: string;
  version: string;
}

/** Contenido de /version.json del frontend. */
export interface FrontendVersionResponse {
  version: string;
}

/** Versiones mostradas en el pie; null significa "no disponible". */
export interface Versions {
  frontend: string | null;
  products: string | null;
  orders: string | null;
}
