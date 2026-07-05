'use client';

import { useEffect, useState } from 'react';
import { platforms, type Platform } from '@/config/site';
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
  const Icon = platformIcon[p.id];
  return (
    <div
      className={`glass relative flex flex-col rounded-2xl p-6 transition ${
        recommended ? 'border-brand-400/50 bg-white/[0.06] ring-1 ring-brand-400/30' : ''
      }`}
    >
      {recommended && (
        <span className="absolute right-4 top-4 rounded-full bg-brand-500/20 px-2.5 py-1 text-[11px] font-semibold uppercase tracking-wide text-brand-200">
          Your device
        </span>
      )}
      <div className="flex items-center gap-3">
        <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-brand-500/15 text-brand-300">
          <Icon className="h-7 w-7" />
        </div>
        <div>
          <h3 className="text-lg font-semibold text-white">{p.os}</h3>
          <p className="text-xs text-slate-400">
            .{p.ext.toLowerCase()} · {p.note}
          </p>
        </div>
      </div>

      {p.comingSoon ? (
        <span className="btn mt-5 w-full cursor-not-allowed border border-white/10 bg-white/5 text-slate-400">
          Coming soon
        </span>
      ) : (
        <a href={p.url} download className="btn-primary mt-5 w-full">
          <DownloadIcon className="h-5 w-5" /> Download {p.ext}
        </a>
      )}

      <ol className="mt-5 space-y-2.5">
        {p.install.map((step, i) => (
          <li key={i} className="flex gap-2.5 text-sm text-slate-300">
            <span className="mt-0.5 flex h-5 w-5 flex-none items-center justify-center rounded-full bg-white/5 text-[11px] text-brand-300">
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
  const [id, setId] = useState<Platform['id'] | null>(null);
  useEffect(() => setId(detect()), []);

  const ordered = [...platforms].sort((a, b) =>
    a.id === id ? -1 : b.id === id ? 1 : 0
  );

  return (
    <section className="container-px py-16">
      <div className="grid gap-5 md:grid-cols-2">
        {ordered.map((p) => (
          <Card key={p.id} p={p} recommended={p.id === id} />
        ))}
      </div>
      <p className="mt-8 flex items-center justify-center gap-2 text-center text-sm text-slate-400">
        <Check className="h-4 w-4 text-brand-400" /> Free forever · No ads · Sync across all your
        devices
      </p>
    </section>
  );
}
