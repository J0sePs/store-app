import { Component } from '@angular/core';

/** Texto del banner de la demo (se cambia aquí en una futura versión). */
export const RELEASE_BANNER_TEXT = 'Versión 2 - desplegada con GitOps';

/** Banner de versión: se muestra debajo de la barra superior en todas las vistas. */
@Component({
  selector: 'app-release-banner',
  templateUrl: './release-banner.html',
})
export class ReleaseBanner {
  protected readonly text = RELEASE_BANNER_TEXT;
}
