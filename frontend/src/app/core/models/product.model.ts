/** Producto devuelto por products-service. */
export interface Product {
  id: number;
  name: string;
  price: number;
  stock: number;
  created_at: string;
}

/** Cuerpo de POST /api/products. */
export interface CreateProductRequest {
  name: string;
  price: number;
  stock: number;
}
