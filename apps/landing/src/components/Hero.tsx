'use client';

import { site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import { GlobeIcon } from './icons';
import PrimaryDownload from './PrimaryDownload';

export default function Hero() {
  const { t } = useLang();
  return (
    <section className="relative overflow-hidden pt-32 pb-20 sm:pt-40 sm:pb-28">
      {/* glow orbs */}
      <div className="pointer-events-none absolute -top-24 left-1/2 -z-10 h-[36rem] w-[36rem] -translate-x-1/2 rounded-full bg-brand-500/20 blur-3xl" />
      <div className="pointer-events-none absolute right-0 top-40 -z-10 h-72 w-72 rounded-full bg-gold-500/10 blur-3xl" />

      <div className="container-px flex flex-col items-center text-center">
        <span className="eyebrow animate-fade-up">✦ {t.hero.eyebrow}</span>

        <h1
          className="mt-6 max-w-4xl font-display text-4xl font-semibold leading-[1.08] tracking-tight text-white animate-fade-up sm:text-6xl"
          style={{ animationDelay: '80ms' }}
        >
          {t.hero.titleA} <span className="gold-text">{t.hero.titleB}</span>
        </h1>

        <p
          className="mt-6 max-w-2xl text-lg text-slate-300 animate-fade-up"
          style={{ animationDelay: '160ms' }}
        >
          {t.hero.subtitle}
        </p>

        <div
          className="mt-10 flex flex-col items-center gap-4 animate-fade-up sm:flex-row"
          style={{ animationDelay: '240ms' }}
        >
          <PrimaryDownload />
          <a href={site.webApp} className="btn-ghost text-base">
            <GlobeIcon className="h-5 w-5" /> {t.cta.openWebApp}
          </a>
        </div>

        <p className="mt-5 text-xs text-slate-500 animate-fade-up" style={{ animationDelay: '320ms' }}>
          {t.hero.freeLine}
        </p>

        {/* device mock */}
        <div
          className="relative mt-16 w-full max-w-4xl animate-fade-up"
          style={{ animationDelay: '400ms' }}
        >
          <div className="glass mx-auto overflow-hidden rounded-3xl p-2 shadow-2xl shadow-black/40">
            <div className="rounded-2xl bg-gradient-to-b from-ink-800 to-ink-900 p-6 sm:p-10">
              <div className="grid gap-4 sm:grid-cols-3">
                {[
                  { t: 'መጽሐፍ ቅዱስ', s: t.hero.cards.bible },
                  { t: 'ውዳሴ ማርያም', s: t.hero.cards.praise },
                  { t: 'ስንክሳር', s: t.hero.cards.synax },
                ].map((c, i) => (
                  <div
                    key={c.t}
                    className="rounded-xl border border-white/10 bg-white/[0.03] p-5 text-left"
                    style={{ transform: `translateY(${i === 1 ? -10 : 0}px)` }}
                  >
                    <div className="mb-6 h-1.5 w-10 rounded-full bg-gold-500/70" />
                    <div className="font-display text-lg text-white">{c.t}</div>
                    <div className="mt-1 text-sm text-slate-400">{c.s}</div>
                    <div className="mt-6 space-y-2">
                      <div className="h-2 w-full rounded-full bg-white/10" />
                      <div className="h-2 w-4/5 rounded-full bg-white/10" />
                      <div className="h-2 w-2/3 rounded-full bg-white/10" />
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
