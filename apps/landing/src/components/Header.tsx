'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import { Logo, ArrowRight } from './icons';

function LangToggle({ className = '' }: { className?: string }) {
  const { lang, setLang } = useLang();
  return (
    <div
      className={`inline-flex items-center rounded-full border border-white/15 p-0.5 text-xs font-semibold ${className}`}
      role="group"
      aria-label="Language"
    >
      <button
        onClick={() => setLang('en')}
        className={`rounded-full px-2.5 py-1 transition ${lang === 'en' ? 'bg-brand-500 text-ink-900' : 'text-slate-300 hover:text-white'}`}
      >
        EN
      </button>
      <button
        onClick={() => setLang('am')}
        className={`rounded-full px-2.5 py-1 transition ${lang === 'am' ? 'bg-brand-500 text-ink-900' : 'text-slate-300 hover:text-white'}`}
      >
        አማ
      </button>
    </div>
  );
}

export default function Header() {
  const { t } = useLang();
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);

  const nav = [
    { href: '/#features', label: t.nav.features },
    { href: '/#platforms', label: t.nav.platforms },
    { href: '/download', label: t.nav.download },
  ];

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <header
      className={`fixed inset-x-0 top-0 z-50 transition-all ${
        scrolled ? 'glass shadow-lg shadow-black/20' : 'bg-transparent'
      }`}
    >
      <div className="container-px flex h-16 items-center justify-between">
        <Link href="/" className="flex items-center gap-2.5">
          <Logo className="h-8 w-8" />
          <span className="flex flex-col leading-none">
            <span className="text-sm font-semibold tracking-tight text-white">{site.name}</span>
            <span className="text-[11px] text-brand-300/80">{site.nameAm}</span>
          </span>
        </Link>

        <nav className="hidden items-center gap-8 md:flex">
          {nav.map((n) => (
            <Link
              key={n.href}
              href={n.href}
              className="text-sm text-slate-300 transition hover:text-white"
            >
              {n.label}
            </Link>
          ))}
        </nav>

        <div className="hidden items-center gap-3 md:flex">
          <LangToggle />
          <a href={site.login} className="text-sm font-medium text-slate-200 hover:text-white">
            {t.cta.login}
          </a>
          <a href={site.register} className="btn-primary">
            {t.cta.getStarted} <ArrowRight className="h-4 w-4" />
          </a>
        </div>

        <button
          aria-label="Menu"
          onClick={() => setOpen((v) => !v)}
          className="flex h-10 w-10 items-center justify-center rounded-lg border border-white/10 md:hidden"
        >
          <div className="space-y-1.5">
            <span className={`block h-0.5 w-5 bg-white transition ${open ? 'translate-y-2 rotate-45' : ''}`} />
            <span className={`block h-0.5 w-5 bg-white transition ${open ? 'opacity-0' : ''}`} />
            <span className={`block h-0.5 w-5 bg-white transition ${open ? '-translate-y-2 -rotate-45' : ''}`} />
          </div>
        </button>
      </div>

      {open && (
        <div className="glass border-t border-white/10 md:hidden">
          <div className="container-px flex flex-col gap-1 py-4">
            {nav.map((n) => (
              <Link
                key={n.href}
                href={n.href}
                onClick={() => setOpen(false)}
                className="rounded-lg px-2 py-2.5 text-slate-200 hover:bg-white/5"
              >
                {n.label}
              </Link>
            ))}
            <div className="mt-3 flex items-center justify-between">
              <LangToggle />
            </div>
            <div className="mt-2 flex gap-3">
              <a href={site.login} className="btn-ghost flex-1">{t.cta.login}</a>
              <a href={site.register} className="btn-primary flex-1">{t.cta.getStarted}</a>
            </div>
          </div>
        </div>
      )}
    </header>
  );
}
