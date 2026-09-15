'use client';

import { useLayoutEffect, useRef, type ReactNode } from 'react';
import { gsap, registerGsap, prefersReducedMotion } from '@/lib/gsap';

export default function Reveal({
  children,
  className = '',
  delay = 0,
}: {
  children: ReactNode;
  className?: string;
  delay?: number;
}) {
  const ref = useRef<HTMLDivElement>(null);

  useLayoutEffect(() => {
    registerGsap();
    const el = ref.current;
    if (!el) return;
    if (prefersReducedMotion()) return;
    const ctx = gsap.context(() => {
      gsap.from(el, {
        opacity: 0,
        y: 28,
        filter: 'blur(10px)',
        duration: 0.85,
        delay: delay / 1000,
        ease: 'power3.out',
        scrollTrigger: { trigger: el, start: 'top 86%' },
      });
    }, el);
    return () => ctx.revert();
  }, [delay]);

  return (
    <div ref={ref} className={className}>
      {children}
    </div>
  );
}
