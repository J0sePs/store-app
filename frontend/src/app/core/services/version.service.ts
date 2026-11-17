import { Injectable, inject } from '@angular/core';
import { Observable, catchError, forkJoin, map, of, switchMap, timer } from 'rxjs';
import { Versions } from '../models/health.model';
import { HealthService } from './health.service';

/** Cada cuántos milisegundos se vuelven a consultar las versiones. */
export const VERSION_POLL_MS = 30_000;

/** Consulta las versiones al cargar y de forma periódica; un fallo no afecta a los demás orígenes. */
@Injectable({ providedIn: 'root' })
export class VersionService {
  private readonly health = inject(HealthService);

  readonly versions$: Observable<Versions> = timer(0, VERSION_POLL_MS).pipe(
    switchMap(() =>
      forkJoin({
        frontend: this.safe(this.health.getFrontendVersion()),
        products: this.safe(this.health.getProductsHealth()),
        orders: this.safe(this.health.getOrdersHealth()),
      }),
    ),
  );

  private safe(source: Observable<{ version: string }>): Observable<string | null> {
    return source.pipe(
      map((response) => response.version),
      catchError(() => of(null)),
    );
  }
}
