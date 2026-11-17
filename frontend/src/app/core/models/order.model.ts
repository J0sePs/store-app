/** Pedido devuelto por orders-service. product_id es solo una referencia. */
export interface Order {
  id: number;
  product_id: number;
  quantity: number;
  customer: string;
  status: string;
  created_at: string;
}

/** Cuerpo de POST /api/orders. */
export interface CreateOrderRequest {
  product_id: number;
  quantity: number;
  customer: string;
}
