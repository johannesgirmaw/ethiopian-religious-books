'use client';

import { useEffect, useState } from 'react';
import { platforms, type Platform } from '@/config/site';
import { useLang, fill } from '@/i18n/LanguageProvider';
import { platformIcon, DownloadIcon, Check } from './icons';

function detect(): Platform['id'] | null {
  if (typeof navigator === 'undefined') return null;
  const ua = navigator.userAgent.toLowerCase();
  if (/android/.test(ua)) return 'android';
  if (/win/.test(ua)) return 'windows';
  if (/mac/.test(ua)) return 'macos';
  if (/linux/.test(ua)) return 'linux';
  return null;
}

function Card({ p, recommended }: { p: Platform; recommended: boolean }) {
  const { t } = useLang();
  const Icon = platformIcon[p.id];
  const copy = t.plat[p.id];
  return (
    <div
      className={`soft-card relative flex flex-col p-6 ${
        recommended ? 'ring-1 ring-brand-400' : ''
      }`}
    >
      {recommended && (
        <span className="absolute right-4 top-4 rounded-full bg-brand-50 px-2.5 py-1 text-[11px] font-semibold uppercase tracking-wide text-brand-600">
          {t.download.yourDevice}
        </span>
      )}
      <div className="flex items-center gap-3">
        <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-brand-50 text-brand-500">
          <Icon className="h-7 w-7" />
        </div>
        <div>
          <h3 className="font-display text-lg font-semibold text-ink-900">{p.os}</h3>
          <p className="text-xs text-slate-500">
            .{p.ext.toLowerCase()} · {copy.note}
          </p>
        </div>
      </div>

      {p.comingSoon ? (
        <span className="btn-pill mt-5 w-full cursor-not-allowed border border-slate-200 bg-slate-50 text-slate-400">
          {t.download.comingSoon}
        </span>
      ) : (
        <a href={p.url} download className="btn-pill mt-5 w-full bg-brand-400 text-white shadow-lg shadow-brand-400/25 hover:bg-brand-500">
          <DownloadIcon className="h-5 w-5" /> {fill(t.download.downloadExt, { ext: p.ext })}
        </a>
      )}

      <ol className="mt-5 space-y-2.5">
        {copy.install.map((step, i) => (
          <li key={i} className="flex gap-2.5 text-sm text-slate-500">
            <span className="mt-0.5 flex h-5 w-5 flex-none items-center justify-center rounded-full bg-brand-50 text-[11px] text-brand-600">
              {i + 1}
            </span>
            <span className="leading-relaxed">{step}</span>
          </li>
        ))}
      </ol>
    </div>
  );
}

export default function DownloadGrid() {
  const { t } = useLang();
  const [id, setId] = useState<Platform['id'] | null>(null);
  useEffect(() => setId(detect()), []);

  const ordered = [...platforms].sort((a, b) => (a.id === id ? -1 : b.id === id ? 1 : 0));

  return (
    <section className="container-px py-16">
      <div className="grid gap-5 md:grid-cols-2">
        {ordered.map((p) => (
          <Card key={p.id} p={p} recommended={p.id === id} />
        ))}
      </div>
      <p className="mt-8 flex items-center justify-center gap-2 text-center text-sm text-slate-500">
        <Check className="h-4 w-4 text-brand-400" /> {t.download.freeNote}
      </p>
    </section>
  );
}
