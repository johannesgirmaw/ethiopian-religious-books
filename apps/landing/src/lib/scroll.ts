import type Lenis from 'lenis';

let instance: Lenis | null = null;

export function setLenis(lenis: Lenis | null) {
  instance = lenis;
}

export function scrollTo(target: string | number, options?: Record<string, unknown>) {
  if (instance) {
    instance.scrollTo(target, options);
    return;
  }
  if (typeof target === 'string') {
    document.querySelector(target)?.scrollIntoView({ behavior: 'smooth' });
    return;
  }
  window.scrollTo({ top: target, behavior: 'smooth' });
}
