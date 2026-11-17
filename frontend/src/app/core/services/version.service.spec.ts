import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { Subscription } from 'rxjs';
import { Versions } from '../models/health.model';
import { VERSION_POLL_MS, VersionService } from './version.service';

describe('VersionService', () => {
  let http: HttpTestingController;
  let subscription: Subscription;
  let emitidos: Versions[];

  beforeEach(() => {
    vi.useFakeTimers();
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    http = TestBed.inject(HttpTestingController);
    emitidos = [];
    subscription = TestBed.inject(VersionService).versions$.subscribe((v) => emitidos.push(v));
  });

  afterEach(() => {
    subscription.unsubscribe();
    vi.useRealTimers();
  });

  function responder(frontend: string | null, products: string | null, orders: string | null): void {
    const respuestas: [string, string | null][] = [
      ['/version.json', frontend],
      ['/api/products/health', products],
      ['/api/orders/health', orders],
    ];
    for (const [url, version] of respuestas) {
      const req = http.expectOne(url);
      if (version === null) {
        req.flush(null, { status: 503, statusText: 'Service Unavailable' });
      } else {
        req.flush({ status: 'ok', version });
      }
    }
  }

  it('consulta al cargar y entrega las tres versiones', () => {
    vi.advanceTimersByTime(0);
    responder('1.0.0', '1.0.1', '1.0.2');
    expect(emitidos).toEqual([{ frontend: '1.0.0', products: '1.0.1', orders: '1.0.2' }]);
  });

  it('un servicio caído no afecta a los demás', () => {
    vi.advanceTimersByTime(0);
    responder('1.0.0', '1.0.1', null);
    expect(emitidos).toEqual([{ frontend: '1.0.0', products: '1.0.1', orders: null }]);
  });

  it('refleja una versión nueva en la siguiente consulta', () => {
    vi.advanceTimersByTime(0);
    responder('1.0.0', '1.0.1', '1.0.2');
    vi.advanceTimersByTime(VERSION_POLL_MS);
    responder('1.0.0', '2.0.0', '1.0.2');
    expect(emitidos).toHaveLength(2);
    expect(emitidos[1].products).toBe('2.0.0');
  });
});
