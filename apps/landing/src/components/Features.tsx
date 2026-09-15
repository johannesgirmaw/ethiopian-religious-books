'use client';

import { useLayoutEffect, useRef } from 'react';
import { site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import WordReveal from './WordReveal';
import {
  BookIcon,
  HighlightIcon,
  OfflineIcon,
  PlanIcon,
  SearchIcon,
} from './icons';
import { gsap, registerGsap, prefersReducedMotion } from '@/lib/gsap';

const ICONS = [BookIcon, OfflineIcon, HighlightIcon, PlanIcon, SearchIcon, BookIcon];

export default function Features() {
  const { t, lang } = useLang();
  const root = useRef<HTMLElement>(null);
  const around = t.features.items.slice(0, 4);
  const rest = t.features.items.slice(4, 6);

  useLayoutEffect(() => {
    registerGsap();
    const el = root.current;
    if (!el) return;
    const ctx = gsap.context(() => {
      if (prefersReducedMotion()) return;
      const cards = el.querySelectorAll('[data-feature]');
      const emblem = el.querySelector('[data-emblem]');
      gsap.from(cards, {
        y: 64,
        opacity: 0,
        rotateX: 8,
        filter: 'blur(12px)',
        duration: 0.9,
        stagger: 0.08,
        ease: 'power3.out',
        scrollTrigger: { trigger: el, start: 'top 72%' },
      });
      gsap.from(emblem, {
        y: -80,
        scale: 0.55,
        rotateY: 28,
        opacity: 0,
        duration: 1.1,
        ease: 'power3.out',
        scrollTrigger: { trigger: el, start: 'top 70%' },
      });
    }, el);
    return () => ctx.revert();
  }, [lang]);

  return (
    <section id="features" ref={root} className="bg-slate-50 py-20 lg:py-28">
      <div className="container-px">
        <div className="mx-auto max-w-3xl text-center">
          <p className="section-label">{t.features.eyebrow}</p>
          <WordReveal
            as="h2"
            text={t.features.heading}
            className="font-display text-3xl font-bold tracking-tight text-ink-900 sm:text-5xl sm:leading-[1.1]"
          />
          <p className="mx-auto mt-4 max-w-xl text-slate-500">{t.features.sub}</p>
        </div>

        <div className="relative mx-auto mt-16 grid max-w-5xl gap-4 lg:grid-cols-[1fr_13rem_1fr] lg:items-center">
          <div className="grid gap-4">
            {around.slice(0, 2).map((item, i) => (
              <FeatureCard key={item.title} item={item} Icon={ICONS[i]} index={i} />
            ))}
          </div>

          <div data-emblem className="relative z-10 mx-auto my-8 lg:my-0">
            <div className="emblem-badge relative flex size-[8.5rem] items-center justify-center rounded-[2rem] bg-ink-900 shadow-[0_30px_70px_rgb(4_24_32/0.28)] lg:size-[13rem] lg:rounded-[2.4rem]">
              <div className="emblem-hatch pointer-events-none absolute inset-3 rounded-[1.4rem] lg:rounded-[1.8rem]" />
              <img src="/logo-mark.png" alt="" className="relative z-10 h-12 w-12 object-contain lg:h-16 lg:w-16" />
            </div>
          </div>

          <div className="grid gap-4">
            {around.slice(2, 4).map((item, i) => (
              <FeatureCard key={item.title} item={item} Icon={ICONS[i + 2]} index={i + 2} />
            ))}
          </div>
        </div>

        <div className="mx-auto mt-4 grid max-w-5xl gap-4 sm:grid-cols-2">
          {rest.map((item, i) => (
            <FeatureCard key={item.title} item={item} Icon={ICONS[i + 4]} index={i + 4} />
          ))}
        </div>

        <div className="mt-10 grid gap-3 sm:grid-cols-3">
          {[
            { href: site.webApp, label: t.cta.openWebApp, code: '01' },
            { href: '/download', label: t.nav.download, code: '02' },
            { href: site.register, label: t.cta.getStarted, code: '03' },
          ].map((pill) => (
            <a
              key={pill.code}
              href={pill.href}
              className="group flex items-center justify-between rounded-full bg-white px-5 py-4 shadow-[0_10px_30px_rgb(4_24_32/0.06)] transition-all hover:-translate-y-0.5 hover:shadow-[0_16px_40px_rgb(4_24_32/0.1)]"
            >
              <span className="flex items-center gap-3">
                <span className="font-mono text-[10px] tracking-[0.22em] text-brand-500">{pill.code}</span>
                <span className="font-display text-sm font-semibold text-ink-900">{pill.label}</span>
              </span>
              <span className="text-brand-500 transition-transform group-hover:translate-x-1">→</span>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
}

function FeatureCard({
  item,
  Icon,
  index,
}: {
  item: { title: string; body: string };
  Icon: typeof BookIcon;
  index: number;
}) {
  return (
    <article
      data-feature
      className="soft-card flex h-full flex-col p-6 will-change-transform"
    >
      <div className="mb-4 flex items-start justify-between">
        <span className="flex size-11 items-center justify-center rounded-2xl bg-brand-50 text-brand-500">
          <Icon className="size-5" />
        </span>
        <span className="font-mono text-[11px] tracking-[0.2em] text-slate-400">
          {String(index + 1).padStart(2, '0')}
        </span>
      </div>
      <h3 className="font-display text-lg font-semibold text-ink-900">{item.title}</h3>
      <p className="mt-2 text-sm leading-relaxed text-slate-500">{item.body}</p>
    </article>
  );
}
