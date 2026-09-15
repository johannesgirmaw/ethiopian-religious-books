'use client';

import Link from 'next/link';
import { platforms, site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import { platformIcon, GlobeIcon, DownloadIcon, ArrowRight } from './icons';
import Reveal from './Reveal';

export default function Platforms() {
  const { t } = useLang();
  return (
    <section id="platforms" className="bg-white py-20 lg:py-28">
      <div className="container-px">
        <Reveal className="mx-auto max-w-3xl text-center">
          <p className="section-label">{t.platforms.eyebrow}</p>
          <h2 className="font-display text-3xl font-bold tracking-tight text-ink-900 sm:text-5xl sm:leading-[1.1]">
            {t.platforms.heading}
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-slate-500">{t.platforms.body}</p>
          <div className="mt-8 flex flex-wrap justify-center gap-3">
            <a href={site.webApp} className="btn-pill border border-ink-900/10 bg-white text-ink-800 hover:border-brand-400">
              <GlobeIcon className="h-5 w-5 text-brand-500" /> {t.platforms.openWebApp}
            </a>
            <Link href="/download" className="btn-pill bg-brand-400 text-white shadow-lg shadow-brand-400/25 hover:bg-brand-500">
              <DownloadIcon className="h-5 w-5" /> {t.platforms.allDownloads}
            </Link>
          </div>
        </Reveal>

        <div className="mt-14 grid grid-cols-2 gap-4 lg:grid-cols-4">
          {platforms.map((p) => {
            const Icon = platformIcon[p.id];
            const note = t.plat[p.id].note;
            const inner = (
              <>
                <span className="flex size-12 items-center justify-center rounded-2xl bg-brand-50 text-brand-500">
                  <Icon className="h-7 w-7" />
                </span>
                <div>
                  <div className="font-display font-semibold text-ink-900">{p.os}</div>
                  <div className="text-xs text-slate-500">
                    {p.comingSoon ? t.download.comingSoon : `.${p.ext.toLowerCase()} · ${note}`}
                  </div>
                </div>
                {!p.comingSoon && (
                  <span className="mt-auto inline-flex items-center gap-1 text-xs font-medium text-brand-600 opacity-0 transition group-hover:opacity-100">
                    {t.nav.download} <ArrowRight className="h-3.5 w-3.5" />
                  </span>
                )}
              </>
            );
            const cls =
              'group flex min-h-[11rem] flex-col gap-3 rounded-[28px] bg-slate-50 p-5 transition duration-300 hover:-translate-y-1 hover:bg-white hover:shadow-[0_18px_40px_rgb(4_24_32/0.08)]';
            return p.comingSoon ? (
              <div key={p.id} className={`${cls} opacity-60`}>{inner}</div>
            ) : (
              <a key={p.id} href={p.url} download className={cls}>{inner}</a>
            );
          })}
        </div>
      </div>
    </section>
  );
}
