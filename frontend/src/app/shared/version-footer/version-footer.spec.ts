import { TestBed } from '@angular/core/testing';
import { Subject, of } from 'rxjs';
import { Versions } from '../../core/models/health.model';
import { VersionService } from '../../core/services/version.service';
import { VersionFooter } from './version-footer';

async function crear(versions$: unknown): Promise<HTMLElement> {
  TestBed.configureTestingModule({
    imports: [VersionFooter],
    providers: [{ provide: VersionService, useValue: { versions$ } }],
  });
  const fixture = TestBed.createComponent(VersionFooter);
  await fixture.whenStable();
  fixture.detectChanges();
  return fixture.nativeElement as HTMLElement;
}

const texto = (el: HTMLElement, clase: string): string | undefined =>
  el.querySelector(clase)?.textContent?.trim();

describe('VersionFooter', () => {
  it('muestra las tres versiones', async () => {
    const el = await crear(of<Versions>({ frontend: '1.0.0', products: '1.0.1', orders: '1.0.2' }));
    expect(texto(el, '.v-frontend')).toBe('1.0.0');
    expect(texto(el, '.v-products')).toBe('1.0.1');
    expect(texto(el, '.v-orders')).toBe('1.0.2');
    expect(el.textContent).toContain('Frontend');
    expect(el.textContent).toContain('Productos');
    expect(el.textContent).toContain('Pedidos');
  });

  it('indica "no disponible" solo para el servicio caído', async () => {
    const el = await crear(of<Versions>({ frontend: '1.0.0', products: '1.0.1', orders: null }));
    expect(texto(el, '.v-orders')).toBe('no disponible');
    expect(texto(el, '.v-products')).toBe('1.0.1');
    expect(texto(el, '.v-frontend')).toBe('1.0.0');
  });

  it('muestra "cargando…" hasta recibir datos', async () => {
    const el = await crear(new Subject<Versions>());
    expect(texto(el, '.v-frontend')).toBe('cargando…');
  });
});
