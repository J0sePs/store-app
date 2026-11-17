import { HttpErrorResponse } from '@angular/common/http';

export const NETWORK_ERROR_MESSAGE = 'No se pudo conectar con el servicio';
export const VALIDATION_ERROR_MESSAGE = 'Los datos enviados no son válidos';
export const UNKNOWN_ERROR_MESSAGE = 'Ocurrió un error inesperado';

/**
 * Traduce un error HTTP de cualquiera de los dos servicios a un mensaje en español.
 * products-service responde {"detail": ...} y orders-service responde {"error": ...}.
 */
export function toUserMessage(error: unknown): string {
  if (!(error instanceof HttpErrorResponse)) {
    return UNKNOWN_ERROR_MESSAGE;
  }
  if (error.status === 0 || error.status >= 500) {
    return NETWORK_ERROR_MESSAGE;
  }
  const body: unknown = error.error;
  if (body && typeof body === 'object') {
    const { detail, error: message } = body as { detail?: unknown; error?: unknown };
    if (typeof detail === 'string' && detail.trim()) {
      return detail;
    }
    if (Array.isArray(detail)) {
      return VALIDATION_ERROR_MESSAGE;
    }
    if (typeof message === 'string' && message.trim()) {
      return message;
    }
  }
  return UNKNOWN_ERROR_MESSAGE;
}
