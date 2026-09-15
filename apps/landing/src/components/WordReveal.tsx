'use client';

import { useLayoutEffect, useRef } from 'react';
import { gsap, registerGsap, prefersReducedMotion } from '@/lib/gsap';

export default function WordReveal({
  text,
  className = '',
  as: Tag = 'p',
}: {
  text: string;
  className?: string;
  as?: 'p' | 'h2' | 'h3' | 'div';
}) {
  const ref = useRef<HTMLElement>(null);

  useLayoutEffect(() => {
    registerGsap();
    const el = ref.current;
    if (!el) return;
    const words = el.querySelectorAll<HTMLElement>('[data-word]');
    if (prefersReducedMotion()) {
      gsap.set(words, { opacity: 1, filter: 'blur(0px)' });
      return;
    }
    const ctx = gsap.context(() => {
      gsap.fromTo(
        words,
        { opacity: 0.12, filter: 'blur(8px)' },
        {
          opacity: 1,
          filter: 'blur(0px)',
          ease: 'none',
          stagger: 0.06,
          scrollTrigger: {
            trigger: el,
            start: 'top 82%',
            end: 'top 36%',
            scrub: 0.8,
          },
        },
      );
    }, el);
    return () => ctx.revert();
  }, [text]);

  return (
    <Tag ref={ref as never} className={className}>
      {text.split(/\s+/).map((word, i) => (
        <span key={`${word}-${i}`} data-word className="mr-[0.28em] inline-block will-change-[opacity,filter]">
          {word}
        </span>
      ))}
    </Tag>
  );
}
