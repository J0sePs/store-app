import { Component, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { VersionService } from '../../core/services/version.service';

/** Pie de página con la versión del frontend y la de cada servicio. */
@Component({
  selector: 'app-version-footer',
  templateUrl: './version-footer.html',
})
export class VersionFooter {
  /** undefined mientras carga; después, un valor por origen (null = no disponible). */
  protected readonly versions = toSignal(inject(VersionService).versions$);

  protected label(version: string | null | undefined): string {
    if (version === undefined) {
      return 'cargando…';
    }
    return version ?? 'no disponible';
  }
}
