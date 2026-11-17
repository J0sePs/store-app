import { AbstractControl, ValidationErrors } from '@angular/forms';

/** Falla si el texto está vacío o solo tiene espacios. */
export function notBlank(control: AbstractControl): ValidationErrors | null {
  const value: unknown = control.value;
  return typeof value === 'string' && value.trim() === '' ? { blank: true } : null;
}

/** Falla si el valor no es un número entero. */
export function integer(control: AbstractControl): ValidationErrors | null {
  const value: unknown = control.value;
  if (value === null || value === '' || value === undefined) {
    return null;
  }
  return Number.isInteger(Number(value)) ? null : { integer: true };
}
