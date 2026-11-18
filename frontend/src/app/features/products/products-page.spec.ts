import { HttpErrorResponse } from '@angular/common/http';
import { TestBed } from '@angular/core/testing';
import { Observable, of, throwError } from 'rxjs';
import { Product } from '../../core/models/product.model';
import { ProductsService } from '../../core/services/products.service';
import { ProductsPage } from './products-page';

const productos: Product[] = [1, 2, 3].map((id) => ({
  id,
  name: `Producto ${id}`,
  category: id === 3 ? 'Monitores' : 'Periféricos',
  price: id * 10,
  stock: id,
  created_at: '2026-01-01T10:00:00Z',
}));

async function crear(
  list: () => Observable<Product[]>,
  create = vi.fn(),
): Promise<{ element: HTMLElement; create: ReturnType<typeof vi.fn>; fixture: ReturnType<typeof TestBed.createComponent<ProductsPage>> }> {
  TestBed.configureTestingModule({
    imports: [ProductsPage],
    providers: [{ provide: ProductsService, useValue: { list, create } }],
  });
  const fixture = TestBed.createComponent(ProductsPage);
  await fixture.whenStable();
  fixture.detectChanges();
  return { element: fixture.nativeElement as HTMLElement, create, fixture };
}

function escribir(element: HTMLElement, id: string, valor: string): void {
  const input = element.querySelector<HTMLInputElement>(`#${id}`)!;
  input.value = valor;
  input.dispatchEvent(new Event('input'));
}

describe('ProductsPage', () => {
  it('muestra una fila por producto', async () => {
    const { element } = await crear(() => of(productos));
    expect(element.querySelectorAll('tbody tr')).toHaveLength(3);
    expect(element.textContent).toContain('Producto 2');
  });

  it('tiene encabezados de columna en español', async () => {
    const { element } = await crear(() => of(productos));
    const encabezados = Array.from(element.querySelectorAll('th')).map((th) => th.textContent?.trim());
    expect(encabezados).toEqual(['ID', 'Nombre', 'Categoría', 'Precio', 'Stock', 'Creado']);
  });

  it('muestra la categoría de cada producto', async () => {
    const { element } = await crear(() => of(productos));
    const celdas = Array.from(element.querySelectorAll('tbody tr')).map((tr) => tr.querySelectorAll('td')[2].textContent?.trim());
    expect(celdas).toEqual(['Periféricos', 'Periféricos', 'Monitores']);
  });

  it('muestra "—" si el servicio no envía la categoría (versión anterior)', async () => {
    const sinCategoria = productos.map((producto) => {
      const copia: Partial<Product> = { ...producto };
      delete copia.category;
      return copia as Product;
    });
    const { element } = await crear(() => of(sinCategoria));
    const celdas = Array.from(element.querySelectorAll('tbody tr')).map((tr) => tr.querySelectorAll('td')[2].textContent?.trim());
    expect(celdas).toEqual(['—', '—', '—']);
    expect(element.querySelectorAll('tbody tr')).toHaveLength(3);
  });

  it('crea un producto con categoría: la envía y la muestra en la fila nueva', async () => {
    const nuevo: Product = { id: 4, name: 'Silla', category: 'Muebles', price: 80, stock: 3, created_at: '2026-01-02T10:00:00Z' };
    const { element, create, fixture } = await crear(() => of(productos), vi.fn(() => of(nuevo)));

    escribir(element, 'product-name', 'Silla');
    escribir(element, 'product-category', '  Muebles ');
    escribir(element, 'product-price', '80');
    escribir(element, 'product-stock', '3');
    fixture.detectChanges();
    element.querySelector('form')!.dispatchEvent(new Event('submit'));
    await fixture.whenStable();
    fixture.detectChanges();

    expect(create).toHaveBeenCalledWith({ name: 'Silla', category: 'Muebles', price: 80, stock: 3 });
    const filas = element.querySelectorAll('tbody tr');
    expect(filas).toHaveLength(4);
    expect(filas[3].querySelectorAll('td')[2].textContent?.trim()).toBe('Muebles');
    expect(element.querySelector<HTMLInputElement>('#product-category')!.value).toBe('');
  });

  it('la categoría vacía no se envía en el cuerpo (el servicio asigna General)', async () => {
    const nuevo: Product = { id: 4, name: 'Cable', category: 'General', price: 3.5, stock: 7, created_at: '2026-01-02T10:00:00Z' };
    const { element, create, fixture } = await crear(() => of(productos), vi.fn(() => of(nuevo)));

    escribir(element, 'product-name', 'Cable');
    escribir(element, 'product-category', '   ');
    escribir(element, 'product-price', '3.5');
    escribir(element, 'product-stock', '7');
    fixture.detectChanges();
    element.querySelector('form')!.dispatchEvent(new Event('submit'));
    await fixture.whenStable();

    expect(create).toHaveBeenCalledTimes(1);
    const cuerpo = create.mock.calls[0][0] as Record<string, unknown>;
    expect(cuerpo).toEqual({ name: 'Cable', price: 3.5, stock: 7 });
    expect('category' in cuerpo).toBe(false);
  });

  it('rechaza una categoría de más de 100 caracteres', async () => {
    const { element, create, fixture } = await crear(() => of(productos));
    escribir(element, 'product-name', 'Silla');
    escribir(element, 'product-category', 'x'.repeat(101));
    escribir(element, 'product-price', '80');
    escribir(element, 'product-stock', '3');
    fixture.detectChanges();
    expect(element.querySelector<HTMLButtonElement>('button[type="submit"]')!.disabled).toBe(true);
    element.querySelector('form')!.dispatchEvent(new Event('submit'));
    fixture.detectChanges();
    expect(create).not.toHaveBeenCalled();
    expect(element.textContent).toContain('La categoría puede tener hasta 100 caracteres');
  });

  it('muestra un mensaje si no hay productos', async () => {
    const { element } = await crear(() => of([]));
    expect(element.textContent).toContain('No hay productos todavía');
  });

  it('muestra el error del servicio', async () => {
    const { element } = await crear(() =>
      throwError(() => new HttpErrorResponse({ status: 0 })),
    );
    expect(element.querySelector('[role="alert"]')?.textContent).toContain('No se pudo conectar con el servicio');
  });

  it('crea un producto válido, lo añade a la tabla y limpia el formulario', async () => {
    const nuevo: Product = { id: 4, name: 'Teclado', price: 25.5, stock: 10, created_at: '2026-01-02T10:00:00Z' };
    const { element, create, fixture } = await crear(() => of(productos), vi.fn(() => of(nuevo)));

    escribir(element, 'product-name', 'Teclado');
    escribir(element, 'product-price', '25.5');
    escribir(element, 'product-stock', '10');
    fixture.detectChanges();
    element.querySelector('form')!.dispatchEvent(new Event('submit'));
    await fixture.whenStable();
    fixture.detectChanges();

    expect(create).toHaveBeenCalledWith({ name: 'Teclado', price: 25.5, stock: 10 });
    expect(element.querySelectorAll('tbody tr')).toHaveLength(4);
    expect(element.querySelector<HTMLInputElement>('#product-name')!.value).toBe('');
  });

  it('no envía nada con datos inválidos', async () => {
    const { element, create, fixture } = await crear(() => of(productos));

    escribir(element, 'product-name', '');
    escribir(element, 'product-price', '0');
    fixture.detectChanges();
    const boton = element.querySelector<HTMLButtonElement>('button[type="submit"]')!;
    expect(boton.disabled).toBe(true);
    element.querySelector('form')!.dispatchEvent(new Event('submit'));
    fixture.detectChanges();

    expect(create).not.toHaveBeenCalled();
    expect(element.textContent).toContain('El nombre es obligatorio');
  });

  it('muestra el error al crear', async () => {
    const fallo = vi.fn(() => throwError(() => new HttpErrorResponse({ status: 422, error: { detail: [{}] } })));
    const { element, fixture } = await crear(() => of(productos), fallo);

    escribir(element, 'product-name', 'X');
    escribir(element, 'product-price', '5');
    fixture.detectChanges();
    element.querySelector('form')!.dispatchEvent(new Event('submit'));
    fixture.detectChanges();

    expect(element.querySelector('[role="alert"]')?.textContent).toContain('Los datos enviados no son válidos');
  });
});
