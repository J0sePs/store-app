import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { toUserMessage } from '../../core/errors/to-user-message';
import { Product } from '../../core/models/product.model';
import { ProductsService } from '../../core/services/products.service';
import { integer, notBlank } from '../../shared/validators';

/** Vista de productos: listado y alta. */
@Component({
  selector: 'app-products-page',
  imports: [ReactiveFormsModule, DatePipe, DecimalPipe],
  templateUrl: './products-page.html',
})
export class ProductsPage implements OnInit {
  private readonly productsService = inject(ProductsService);

  protected readonly products = signal<Product[]>([]);
  protected readonly loading = signal(true);
  protected readonly saving = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly formError = signal<string | null>(null);

  protected readonly form = new FormGroup({
    name: new FormControl('', { nonNullable: true, validators: [Validators.required, notBlank] }),
    price: new FormControl<number | null>(null, [Validators.required, Validators.min(0.01)]),
    stock: new FormControl<number | null>(0, [Validators.required, Validators.min(0), integer]),
  });

  ngOnInit(): void {
    this.productsService.list().subscribe({
      next: (products) => {
        this.products.set(products);
        this.loading.set(false);
      },
      error: (error: unknown) => {
        this.loadError.set(toUserMessage(error));
        this.loading.set(false);
      },
    });
  }

  protected submit(): void {
    if (this.form.invalid || this.saving()) {
      this.form.markAllAsTouched();
      return;
    }
    const { name, price, stock } = this.form.getRawValue();
    this.saving.set(true);
    this.formError.set(null);
    this.productsService.create({ name: name.trim(), price: Number(price), stock: Number(stock) }).subscribe({
      next: (created) => {
        this.products.update((list) => [...list, created]);
        this.form.reset({ name: '', price: null, stock: 0 });
        this.saving.set(false);
      },
      error: (error: unknown) => {
        this.formError.set(toUserMessage(error));
        this.saving.set(false);
      },
    });
  }
}
