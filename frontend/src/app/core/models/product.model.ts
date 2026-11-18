/** Producto devuelto por products-service. */
export interface Product {
  id: number;
  name: string;
  /** Opcional: un servicio todavía en la versión anterior no lo envía. */
  category?: string;
  price: number;
  stock: number;
  created_at: string;
}

/** Cuerpo de POST /api/products. */
export interface CreateProductRequest {
  name: string;
  price: number;
  stock: number;
  /** Opcional: si se omite, el servicio asigna "General". */
  category?: string;
}
