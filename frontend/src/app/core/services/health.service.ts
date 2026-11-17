import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { FrontendVersionResponse, HealthResponse } from '../models/health.model';

/** Consulta la versión del frontend y el /health de cada servicio. */
@Injectable({ providedIn: 'root' })
export class HealthService {
  private readonly http = inject(HttpClient);

  getFrontendVersion(): Observable<FrontendVersionResponse> {
    return this.http.get<FrontendVersionResponse>('/version.json');
  }

  getProductsHealth(): Observable<HealthResponse> {
    return this.http.get<HealthResponse>('/api/products/health');
  }

  getOrdersHealth(): Observable<HealthResponse> {
    return this.http.get<HealthResponse>('/api/orders/health');
  }
}
