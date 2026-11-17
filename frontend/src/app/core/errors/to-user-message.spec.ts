import { HttpErrorResponse } from '@angular/common/http';
import {
  NETWORK_ERROR_MESSAGE,
  UNKNOWN_ERROR_MESSAGE,
  VALIDATION_ERROR_MESSAGE,
  toUserMessage,
} from './to-user-message';

function httpError(status: number, body: unknown): HttpErrorResponse {
  return new HttpErrorResponse({ status, error: body });
}

describe('toUserMessage', () => {
  const casos: [string, unknown, string][] = [
    ['formato detail', httpError(404, { detail: 'Producto no encontrado' }), 'Producto no encontrado'],
    ['formato error', httpError(400, { error: 'quantity debe ser mayor que 0' }), 'quantity debe ser mayor que 0'],
    ['detail como lista (422)', httpError(422, { detail: [{ msg: 'x' }] }), VALIDATION_ERROR_MESSAGE],
    ['error de red (estado 0)', httpError(0, null), NETWORK_ERROR_MESSAGE],
    ['error 500', httpError(500, { error: 'Error interno del servidor' }), NETWORK_ERROR_MESSAGE],
    ['error 503 sin cuerpo', httpError(503, null), NETWORK_ERROR_MESSAGE],
    ['4xx sin cuerpo útil', httpError(400, 'texto'), UNKNOWN_ERROR_MESSAGE],
    ['valor que no es HttpErrorResponse', new Error('x'), UNKNOWN_ERROR_MESSAGE],
  ];

  it.each(casos)('%s', (_nombre, error, esperado) => {
    expect(toUserMessage(error)).toBe(esperado);
  });
});
