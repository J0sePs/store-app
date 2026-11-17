import { HttpErrorResponse } from '@angular/common/http';
import { TestBed } from '@angular/core/testing';
import { Observable, of, throwError } from 'rxjs';
import { Order } from '../../core/models/order.model';
import { Product } from '../../core/models/product.model';
import { OrdersService } from '../../core/services/orders.service';
import { ProductsService } from '../../core/services/products.service';
import { OrdersPage } from './orders-page';

const productos: Product[] = [
  { id: 1, name: 'Teclado', price: 10, stock: 5, created_at: '2026-01-01T10:00:00Z' },
  { id: 2, name: 'Mouse', price: 5, stock: 8, created_at: '2026-01-01T10:00:00Z' },
];

const pedido = (id: number, productId: number): Order => ({
  id,
  product_id: productId,
  quantity: 2,
  customer: 'Ana',
  status: 'pending',
  created_at: '2026-01-02T10:00:00Z',
});

async function crear(opciones: {
  products?: () => Observable<Product[]>;
  orders?: () => Observable<Order[]>;
  create?: ReturnType<typeof vi.fn>;
}) {
  const create = opciones.create ?? vi.fn();
  TestBed.configureTestingModule({
    imports: [OrdersPage],
    providers: [
      { provide: ProductsService, useValue: { list: opciones.products ?? (() => of(productos)) } },
      { provide: OrdersService, useValue: { list: opciones.orders ?? (() => of([])), create } },
    ],
  });
  const fixture = TestBed.createComponent(OrdersPage);
  await fixture.whenStable();
  fixture.detectChanges();
  return { fixture, element: fixture.nativeElement as HTMLElement, create };
}

function rellenar(element: HTMLElement, producto: string, cantidad: string, cliente: string): void {
  const select = element.querySelector<HTMLSelectElement>('#order-product')!;
  select.selectedIndex = Array.from(select.options).findIndex((o) => o.text.trim() === producto);
  select.dispatchEvent(new Event('change'));
  for (const [id, valor] of [
    ['order-quantity', cantidad],
    ['order-customer', cliente],
  ]) {
    const input = element.querySelector<HTMLInputElement>(`#${id}`)!;
    input.value = valor;
    input.dispatchEvent(new Event('input'));
  }
}

describe('OrdersPage', () => {
  it('resuelve el nombre del producto de cada pedido', async () => {
    const { element } = await crear({ orders: () => of([pedido(1, 1), pedido(2, 2)]) });
    const filas = Array.from(element.querySelectorAll('tbody tr')).map((tr) => tr.textContent);
    expect(filas[0]).toContain('Teclado');
    expect(filas[1]).toContain('Mouse');
  });

  it('muestra "Producto #id" si el producto no está en la lista', async () => {
    const { element } = await crear({ orders: () => of([pedido(1, 99)]) });
    expect(element.querySelector('tbody')?.textContent).toContain('Producto #99');
  });

  it('muestra un mensaje si no hay pedidos', async () => {
    const { element } = await crear({});
    expect(element.textContent).toContain('No hay pedidos todavía');
  });

  it('el selector ofrece una opción por producto', async () => {
    const { element } = await crear({});
    const opciones = Array.from(element.querySelectorAll('#order-product option')).map((o) => o.textContent?.trim());
    expect(opciones).toEqual(['Elige un producto', 'Teclado', 'Mouse']);
  });

  it('crea un pedido con el product_id elegido y lo añade a la tabla', async () => {
    const create = vi.fn(() => of(pedido(1, 2)));
    const { element, fixture } = await crear({ create });

    rellenar(element, 'Mouse', '3', ' Ana ');
    fixture.detectChanges();
    element.querySelector('form')!.dispatchEvent(new Event('submit'));
    await fixture.whenStable();
    fixture.detectChanges();

    expect(create).toHaveBeenCalledWith({ product_id: 2, quantity: 3, customer: 'Ana' });
    expect(element.querySelectorAll('tbody tr')).toHaveLength(1);
    expect(element.textContent).toContain('pending');
  });

  it('bloquea el formulario sin productos', async () => {
    const { element, create } = await crear({ products: () => of([]) });
    expect(element.textContent).toContain('Primero crea un producto');
    expect(element.querySelector('form')).toBeNull();
    expect(create).not.toHaveBeenCalled();
  });

  it('muestra el mensaje {"error": ...} del servicio ante un 400', async () => {
    const create = vi.fn(() =>
      throwError(() => new HttpErrorResponse({ status: 400, error: { error: 'quantity debe ser mayor que 0' } })),
    );
    const { element, fixture } = await crear({ create });

    rellenar(element, 'Teclado', '1', 'Ana');
    fixture.detectChanges();
    element.querySelector('form')!.dispatchEvent(new Event('submit'));
    fixture.detectChanges();

    expect(element.querySelector('[role="alert"]')?.textContent).toContain('quantity debe ser mayor que 0');
  });

  it('muestra un error si falla la carga', async () => {
    const { element } = await crear({ orders: () => throwError(() => new HttpErrorResponse({ status: 0 })) });
    expect(element.querySelector('[role="alert"]')?.textContent).toContain('No se pudo conectar con el servicio');
  });
});
