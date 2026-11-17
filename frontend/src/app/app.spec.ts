import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { of } from 'rxjs';
import { App } from './app';
import { routes } from './app.routes';
import { OrdersService } from './core/services/orders.service';
import { ProductsService } from './core/services/products.service';
import { VersionService } from './core/services/version.service';

async function crear() {
  TestBed.configureTestingModule({
    imports: [App],
    providers: [
      provideRouter(routes),
      { provide: ProductsService, useValue: { list: () => of([]), create: vi.fn() } },
      { provide: OrdersService, useValue: { list: () => of([]), create: vi.fn() } },
      { provide: VersionService, useValue: { versions$: of({ frontend: 'dev', products: 'dev', orders: null }) } },
    ],
  });
  const fixture = TestBed.createComponent(App);
  await TestBed.inject(Router).navigateByUrl('/');
  await fixture.whenStable();
  fixture.detectChanges();
  return { fixture, element: fixture.nativeElement as HTMLElement, router: TestBed.inject(Router) };
}

describe('App', () => {
  it('muestra la vista de productos en la ruta inicial', async () => {
    const { element, router } = await crear();
    expect(router.url).toBe('/products');
    expect(element.querySelector('h2')?.textContent).toBe('Productos');
  });

  it('navega a pedidos sin recargar la página', async () => {
    const { fixture, element, router } = await crear();
    const enlace = Array.from(element.querySelectorAll('nav a')).find((a) => a.textContent?.trim() === 'Pedidos');
    (enlace as HTMLAnchorElement).click();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(router.url).toBe('/orders');
    expect(element.querySelector('h2')?.textContent).toBe('Pedidos');
  });

  it('muestra el pie de página con las versiones en todas las vistas', async () => {
    const { element } = await crear();
    expect(element.querySelector('footer')?.textContent).toContain('Frontend');
    expect(element.querySelector('footer')?.textContent).toContain('no disponible');
  });
});
