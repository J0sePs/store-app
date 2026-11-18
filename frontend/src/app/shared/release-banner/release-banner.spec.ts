import { TestBed } from '@angular/core/testing';
import { RELEASE_BANNER_TEXT, ReleaseBanner } from './release-banner';

describe('ReleaseBanner', () => {
  it('muestra el texto exacto de la versión 2', async () => {
    TestBed.configureTestingModule({ imports: [ReleaseBanner] });
    const fixture = TestBed.createComponent(ReleaseBanner);
    await fixture.whenStable();
    const el = fixture.nativeElement as HTMLElement;
    expect(RELEASE_BANNER_TEXT).toBe('Versión 2 - desplegada con GitOps');
    expect(el.querySelector('[role="status"]')?.textContent?.trim()).toBe('Versión 2 - desplegada con GitOps');
  });
});
