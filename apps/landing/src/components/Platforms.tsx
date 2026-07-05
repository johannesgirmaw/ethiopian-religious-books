'use client';

import Link from 'next/link';
import { platforms, site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import { platformIcon, GlobeIcon, DownloadIcon, ArrowRight } from './icons';

export default function Platforms() {
  const { t } = useLang();
  return (
    <section id="platforms" className="py-24">
      <div className="container-px">
        <div className="glass overflow-hidden rounded-3xl">
          <div className="grid gap-10 p-8 sm:p-12 lg:grid-cols-2 lg:items-center">
            <div>
              <span className="eyebrow">{t.platforms.eyebrow}</span>
              <h2 className="mt-5 font-display text-3xl font-semibold text-white sm:text-4xl">
                {t.platforms.heading}
              </h2>
              <p className="mt-4 text-slate-300">{t.platforms.body}</p>

              <div className="mt-8 flex flex-wrap gap-3">
                <a href={site.webApp} className="btn-ghost">
                  <GlobeIcon className="h-5 w-5" /> {t.platforms.openWebApp}
                </a>
                <Link href="/download" className="btn-primary">
                  <DownloadIcon className="h-5 w-5" /> {t.platforms.allDownloads}
                </Link>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              {platforms.map((p) => {
                const Icon = platformIcon[p.id];
                const note = t.plat[p.id].note;
                const cls =
                  'group flex flex-col gap-3 rounded-2xl border border-white/10 bg-white/[0.03] p-5 transition hover:border-brand-400/50 hover:bg-white/[0.06]';
                const inner = (
                  <>
                    <Icon className="h-8 w-8 text-brand-300" />
                    <div>
                      <div className="font-semibold text-white">{p.os}</div>
                      <div className="text-xs text-slate-400">
                        {p.comingSoon ? t.download.comingSoon : `.${p.ext.toLowerCase()} · ${note}`}
                      </div>
                    </div>
                    {!p.comingSoon && (
                      <span className="mt-1 inline-flex items-center gap-1 text-xs font-medium text-brand-300 opacity-0 transition group-hover:opacity-100">
                        {t.nav.download} <ArrowRight className="h-3.5 w-3.5" />
                      </span>
                    )}
                  </>
                );
                return p.comingSoon ? (
                  <div key={p.id} className={`${cls} opacity-60`}>{inner}</div>
                ) : (
                  <a key={p.id} href={p.url} download className={cls}>{inner}</a>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
