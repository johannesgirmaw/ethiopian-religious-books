'use client';

import { site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import { ArrowRight, GlobeIcon } from './icons';

export default function CTA() {
  const { t } = useLang();
  return (
    <section className="py-20">
      <div className="container-px">
        <div className="relative overflow-hidden rounded-3xl border border-brand-400/20 bg-gradient-to-br from-brand-700/40 via-ink-800 to-ink-900 p-10 text-center sm:p-16">
          <div className="pointer-events-none absolute -top-20 left-1/2 h-64 w-64 -translate-x-1/2 rounded-full bg-brand-500/20 blur-3xl" />
          <h2 className="mx-auto max-w-2xl font-display text-3xl font-semibold text-white sm:text-4xl">
            {t.ctaSection.heading}
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-slate-300">{t.ctaSection.body}</p>
          <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <a href={site.register} className="btn-primary text-base">
              {t.ctaSection.createAccount} <ArrowRight className="h-4 w-4" />
            </a>
            <a href={site.webApp} className="btn-ghost text-base">
              <GlobeIcon className="h-5 w-5" /> {t.ctaSection.openWebApp}
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}
