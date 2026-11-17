import { DatePipe } from '@angular/common';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { toUserMessage } from '../../core/errors/to-user-message';
import { Order } from '../../core/models/order.model';
import { Product } from '../../core/models/product.model';
import { OrdersService } from '../../core/services/orders.service';
import { ProductsService } from '../../core/services/products.service';
import { integer, notBlank } from '../../shared/validators';

/** Vista de pedidos: listado y alta, eligiendo el producto de una lista. */
@Component({
  selector: 'app-orders-page',
  imports: [ReactiveFormsModule, DatePipe],
  templateUrl: './orders-page.html',
})
export class OrdersPage implements OnInit {
  private readonly ordersService = inject(OrdersService);
  private readonly productsService = inject(ProductsService);

  protected readonly orders = signal<Order[]>([]);
  protected readonly products = signal<Product[]>([]);
  protected readonly loading = signal(true);
  protected readonly saving = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly formError = signal<string | null>(null);

  /** product_id → nombre, para mostrar el producto de cada pedido. */
  private readonly productNames = computed(
    () => new Map(this.products().map((product) => [product.id, product.name])),
  );

  protected readonly form = new FormGroup({
    product_id: new FormControl<number | null>(null, [Validators.required]),
    quantity: new FormControl<number | null>(1, [Validators.required, Validators.min(1), integer]),
    customer: new FormControl('', { nonNullable: true, validators: [Validators.required, notBlank] }),
  });

  ngOnInit(): void {
    forkJoin({ products: this.productsService.list(), orders: this.ordersService.list() }).subscribe({
      next: ({ products, orders }) => {
        this.products.set(products);
        this.orders.set(orders);
        this.loading.set(false);
      },
      error: (error: unknown) => {
        this.loadError.set(toUserMessage(error));
        this.loading.set(false);
      },
    });
  }

  /** Nombre del producto, o "Producto #id" si no está en la lista. */
  protected productName(productId: number): string {
    return this.productNames().get(productId) ?? `Producto #${productId}`;
  }

  protected submit(): void {
    if (this.form.invalid || this.saving() || this.products().length === 0) {
      this.form.markAllAsTouched();
      return;
    }
    const { product_id, quantity, customer } = this.form.getRawValue();
    this.saving.set(true);
    this.formError.set(null);
    this.ordersService
      .create({ product_id: Number(product_id), quantity: Number(quantity), customer: customer.trim() })
      .subscribe({
        next: (created) => {
          this.orders.update((list) => [...list, created]);
          this.form.reset({ product_id: null, quantity: 1, customer: '' });
          this.saving.set(false);
        },
        error: (error: unknown) => {
          this.formError.set(toUserMessage(error));
          this.saving.set(false);
        },
      });
  }
}
