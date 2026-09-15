'use client';

import { site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import Reveal from './Reveal';
import {
  BookIcon,
  HighlightIcon,
  OfflineIcon,
  PlanIcon,
  SearchIcon,
} from './icons';

const ICONS = [BookIcon, OfflineIcon, HighlightIcon, PlanIcon, SearchIcon, BookIcon];

export default function Features() {
  const { t } = useLang();
  const left = t.features.items.slice(0, 3);
  const right = t.features.items.slice(3, 6);

  return (
    <section id="features" className="bg-slate-50 py-20 lg:py-28">
      <div className="container-px">
        <Reveal className="mx-auto max-w-3xl text-center">
          <p className="section-label">{t.features.eyebrow}</p>
          <h2 className="font-display text-3xl font-bold tracking-tight text-ink-900 sm:text-5xl sm:leading-[1.1]">
            {t.features.heading}
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-slate-500">{t.features.sub}</p>
        </Reveal>

        <div className="mt-14 grid gap-6 lg:grid-cols-2">
          {[left, right].map((group, gi) => (
            <Reveal key={gi} delay={gi * 80}>
              <article className="soft-card flex h-full flex-col p-6 sm:p-8">
                <div className="rounded-[24px] bg-brand-50 p-4 sm:p-5">
                  <ul className="space-y-3">
                    {group.map((item, i) => {
                      const Icon = ICONS[gi * 3 + i];
                      return (
                        <li
                          key={item.title}
                          className="flex items-start gap-3 rounded-2xl bg-white px-4 py-3 shadow-[0_8px_24px_rgb(4_24_32/0.05)]"
                        >
                          <span className="mt-0.5 flex size-9 shrink-0 items-center justify-center rounded-xl bg-brand-400/10 text-brand-500">
                            <Icon className="size-4" />
                          </span>
                          <span>
                            <span className="block text-sm font-semibold text-ink-900">{item.title}</span>
                            <span className="mt-0.5 block text-xs leading-relaxed text-slate-500">{item.body}</span>
                          </span>
                        </li>
                      );
                    })}
                  </ul>
                </div>
              </article>
            </Reveal>
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
