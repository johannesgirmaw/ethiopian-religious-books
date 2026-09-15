'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import BrandMark from './BrandMark';

function LangToggle() {
  const { lang, setLang, t } = useLang();
  return (
    <div
      className="inline-flex items-center rounded-full border border-ink-900/[0.06] bg-white p-0.5 text-xs font-semibold"
      role="group"
      aria-label={t.langAria}
    >
      <button
        onClick={() => setLang('en')}
        className={`rounded-full px-2.5 py-1 transition ${lang === 'en' ? 'bg-brand-400 text-white' : 'text-slate-500 hover:text-ink-900'}`}
      >
        EN
      </button>
      <button
        onClick={() => setLang('am')}
        className={`rounded-full px-2.5 py-1 transition ${lang === 'am' ? 'bg-brand-400 text-white' : 'text-slate-500 hover:text-ink-900'}`}
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
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <header className="fixed top-0 z-50 w-full pt-[env(safe-area-inset-top)]">
      <div className="mx-auto max-w-7xl px-3 pt-3 sm:px-5">
        <div
          className={`flex h-14 items-center justify-between gap-3 rounded-full border border-ink-900/[0.06] bg-white/80 px-2.5 pl-3 backdrop-blur-xl transition-shadow duration-500 sm:h-16 ${
            scrolled
              ? 'shadow-[0_10px_40px_rgb(4_24_32/0.08)]'
              : 'shadow-[0_8px_30px_rgb(4_24_32/0.04)]'
          }`}
        >
          <Link href="/" className="shrink-0" aria-label={site.name}>
            <BrandMark />
          </Link>

          <nav className="hidden items-center lg:flex">
            {nav.map((n) => (
              <Link
                key={n.href}
                href={n.href}
                className="rounded-full px-3 py-1.5 text-[13px] font-medium text-ink-900/55 transition-colors hover:text-ink-900"
              >
                {n.label}
              </Link>
            ))}
          </nav>

          <div className="hidden items-center gap-1.5 md:flex">
            <LangToggle />
            <a
              href={site.login}
              className="rounded-full px-3 py-2 text-[13px] font-medium text-ink-900/70 hover:text-ink-900"
            >
              {t.cta.login}
            </a>
            <a
              href={site.register}
              className="inline-flex rounded-full bg-ink-900 px-4 py-2 text-[13px] font-semibold text-white transition-colors hover:bg-brand-600"
            >
              {t.cta.getStarted}
            </a>
          </div>

          <button
            aria-label={t.menuAria}
            onClick={() => setOpen((v) => !v)}
            className="flex size-10 items-center justify-center rounded-full text-ink-900 md:hidden"
          >
            <div className="space-y-1.5">
              <span className={`block h-0.5 w-5 bg-ink-900 transition ${open ? 'translate-y-2 rotate-45' : ''}`} />
              <span className={`block h-0.5 w-5 bg-ink-900 transition ${open ? 'opacity-0' : ''}`} />
              <span className={`block h-0.5 w-5 bg-ink-900 transition ${open ? '-translate-y-2 -rotate-45' : ''}`} />
            </div>
          </button>
        </div>

        {open && (
          <div className="mt-2 rounded-[24px] border border-ink-900/[0.06] bg-white/95 p-4 shadow-lg backdrop-blur-xl md:hidden">
            <div className="flex flex-col gap-1">
              {nav.map((n) => (
                <Link
                  key={n.href}
                  href={n.href}
                  onClick={() => setOpen(false)}
                  className="rounded-full px-3 py-2.5 text-ink-900 hover:bg-brand-50"
                >
                  {n.label}
                </Link>
              ))}
              <div className="mt-2 flex items-center justify-between px-1">
                <LangToggle />
              </div>
              <div className="mt-2 flex gap-2">
                <a href={site.login} className="btn-ghost flex-1">{t.cta.login}</a>
                <a href={site.register} className="btn-primary flex-1">{t.cta.getStarted}</a>
              </div>
            </div>
          </div>
        )}
      </div>
    </header>
  );
}
