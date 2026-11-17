import { Component } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { VersionFooter } from '../version-footer/version-footer';

/** Estructura general: cabecera con navegación, contenido y pie de página con versiones. */
@Component({
  selector: 'app-shell',
  imports: [RouterLink, RouterLinkActive, RouterOutlet, VersionFooter],
  templateUrl: './app-shell.html',
})
export class AppShell {}
