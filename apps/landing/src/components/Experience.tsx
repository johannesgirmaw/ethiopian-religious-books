'use client';

import { useLayoutEffect, useRef } from 'react';
import { useLang } from '@/i18n/LanguageProvider';
import WordReveal from './WordReveal';
import { gsap, registerGsap, prefersReducedMotion } from '@/lib/gsap';

function parseStat(value: string) {
  const match = value.match(/^(\d+)(.*)$/);
  if (!match) return { num: 0, suffix: value };
  return { num: Number(match[1]), suffix: match[2] };
}

export default function Experience() {
  const { t, lang } = useLang();
  const root = useRef<HTMLElement>(null);

  useLayoutEffect(() => {
    registerGsap();
    const el = root.current;
    if (!el) return;
    const ctx = gsap.context(() => {
      const numbers = el.querySelectorAll<HTMLElement>('[data-count]');
      if (prefersReducedMotion()) return;
      numbers.forEach((node) => {
        const target = Number(node.dataset.count);
        const suffix = node.dataset.suffix ?? '';
        const obj = { val: 0 };
        node.textContent = `0${suffix}`;
        gsap.to(obj, {
          val: target,
          duration: 1.4,
          ease: 'power2.out',
          scrollTrigger: { trigger: node, start: 'top 85%' },
          onUpdate: () => {
            node.textContent = `${Math.round(obj.val)}${suffix}`;
          },
        });
      });
    }, el);
    return () => ctx.revert();
  }, [lang]);

  return (
    <section id="experience" ref={root} className="bg-white py-20 lg:py-28">
      <div className="container-px text-center">
        <p className="section-label">{t.experience.eyebrow}</p>
        <WordReveal
          as="h2"
          text={t.experience.heading}
          className="mx-auto max-w-3xl font-display text-3xl font-bold tracking-tight text-ink-900 sm:text-5xl sm:leading-[1.1]"
        />
        <div className="mx-auto mt-14 grid max-w-3xl grid-cols-3 gap-4">
          {t.experience.stats.map((stat) => {
            const { num, suffix } = parseStat(stat.value);
            return (
              <div key={stat.label}>
                <div
                  data-count={num}
                  data-suffix={suffix}
                  className="font-display text-3xl font-bold text-ink-900 sm:text-5xl"
                >
                  {stat.value}
                </div>
                <div className="mt-2 text-xs uppercase tracking-[0.18em] text-slate-500 sm:text-sm">
                  {stat.label}
                </div>
              </div>
            );
          })}
        </div>
        <div className="mx-auto mt-16 max-w-2xl border-t border-ink-900/10 pt-10">
          <WordReveal
            text={t.experience.body}
            className="text-lg leading-relaxed text-ink-900 sm:text-2xl sm:leading-snug"
          />
        </div>
      </div>
    </section>
  );
}
