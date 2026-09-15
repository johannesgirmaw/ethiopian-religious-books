'use client';

import { site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import { ArrowRight, GlobeIcon } from './icons';
import Reveal from './Reveal';

export default function CTA() {
  const { t } = useLang();
  return (
    <section className="relative overflow-hidden bg-ink-900 py-24 text-white lg:py-32">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(ellipse 60% 50% at 50% 0%, rgb(41 182 224 / 0.22), transparent 55%)',
        }}
      />
      <Reveal className="relative mx-auto max-w-4xl px-5 text-center lg:px-8">
        <span className="mb-6 inline-flex rounded-full bg-brand-400 px-3 py-1 text-xs font-semibold text-white">
          {t.cta.getStarted}
        </span>
        <h2 className="font-display text-3xl font-bold tracking-tight sm:text-5xl sm:leading-[1.15]">
          {t.ctaSection.heading}
        </h2>
        <p className="mx-auto mt-5 max-w-xl text-white/70">{t.ctaSection.body}</p>
        <div className="mt-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <a
            href={site.register}
            className="btn-pill bg-brand-400 text-white shadow-lg shadow-brand-400/30 hover:bg-brand-500"
          >
            {t.ctaSection.createAccount} <ArrowRight className="h-4 w-4" />
          </a>
          <a
            href={site.webApp}
            className="btn-pill border border-white/15 bg-white/5 text-white hover:border-brand-300 hover:text-brand-300"
          >
            <GlobeIcon className="h-5 w-5" /> {t.ctaSection.openWebApp}
          </a>
        </div>
      </Reveal>
    </section>
  );
}
