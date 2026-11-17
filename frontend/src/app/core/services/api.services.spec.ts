import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { HealthService } from './health.service';
import { OrdersService } from './orders.service';
import { ProductsService } from './products.service';

describe('Servicios HTTP', () => {
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('ProductsService.list hace GET /api/products', () => {
    TestBed.inject(ProductsService).list().subscribe();
    const req = http.expectOne('/api/products');
    expect(req.request.method).toBe('GET');
    req.flush([]);
  });

  it('ProductsService.create hace POST /api/products con el cuerpo', () => {
    const body = { name: 'Teclado', price: 25.5, stock: 10 };
    TestBed.inject(ProductsService).create(body).subscribe();
    const req = http.expectOne('/api/products');
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual(body);
    req.flush({ ...body, id: 1, created_at: '2026-01-01T00:00:00Z' });
  });

  it('OrdersService.list hace GET /api/orders', () => {
    TestBed.inject(OrdersService).list().subscribe();
    const req = http.expectOne('/api/orders');
    expect(req.request.method).toBe('GET');
    req.flush([]);
  });

  it('OrdersService.create hace POST /api/orders con product_id', () => {
    const body = { product_id: 3, quantity: 2, customer: 'Ana' };
    TestBed.inject(OrdersService).create(body).subscribe();
    const req = http.expectOne('/api/orders');
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual(body);
    req.flush({ ...body, id: 1, status: 'pending', created_at: '2026-01-01T00:00:00Z' });
  });

  it('HealthService usa rutas relativas para las tres versiones', () => {
    const health = TestBed.inject(HealthService);
    health.getFrontendVersion().subscribe();
    health.getProductsHealth().subscribe();
    health.getOrdersHealth().subscribe();
    http.expectOne('/version.json').flush({ version: 'dev' });
    http.expectOne('/api/products/health').flush({ status: 'ok', version: 'dev' });
    http.expectOne('/api/orders/health').flush({ status: 'ok', version: 'dev' });
  });
});
