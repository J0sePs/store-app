import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'products' },
  {
    path: 'products',
    title: 'Productos',
    loadComponent: () => import('./features/products/products-page').then((m) => m.ProductsPage),
  },
  {
    path: 'orders',
    title: 'Pedidos',
    loadComponent: () => import('./features/orders/orders-page').then((m) => m.OrdersPage),
  },
  { path: '**', redirectTo: 'products' },
];
