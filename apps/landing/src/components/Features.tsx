'use client';

import { useLang } from '@/i18n/LanguageProvider';

const icons = ['📖', '📥', '🖍️', '🗓️', '🔎', '🔄'];

export default function Features() {
  const { t } = useLang();
  return (
    <section id="features" className="py-24">
      <div className="container-px">
        <div className="mx-auto max-w-2xl text-center">
          <span className="eyebrow">{t.features.eyebrow}</span>
          <h2 className="mt-5 font-display text-3xl font-semibold text-white sm:text-4xl">
            {t.features.heading}
          </h2>
          <p className="mt-4 text-slate-300">{t.features.sub}</p>
        </div>

        <div className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {t.features.items.map((f, i) => (
            <div
              key={f.title}
              className="glass group rounded-2xl p-6 transition hover:border-brand-400/40 hover:bg-white/[0.06]"
            >
              <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-brand-500/15 text-2xl">
                {icons[i]}
              </div>
              <h3 className="mt-5 text-lg font-semibold text-white">{f.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-slate-400">{f.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
