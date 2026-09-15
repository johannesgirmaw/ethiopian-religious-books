'use client';

import { useLayoutEffect, useRef } from 'react';
import Link from 'next/link';
import { site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import BrandMark from './BrandMark';
import { ArrowUp } from './icons';
import { gsap, registerGsap, prefersReducedMotion } from '@/lib/gsap';
import { scrollTo } from '@/lib/scroll';

export default function Footer() {
  const { t, lang } = useLang();
  const root = useRef<HTMLElement>(null);

  useLayoutEffect(() => {
    registerGsap();
    const el = root.current;
    if (!el) return;
    const ctx = gsap.context(() => {
      if (prefersReducedMotion()) return;
      gsap.from('[data-giant]', {
        yPercent: 28,
        opacity: 0.12,
        ease: 'none',
        scrollTrigger: {
          trigger: el,
          start: 'top 90%',
          end: 'bottom bottom',
          scrub: 0.8,
        },
      });
    }, el);
    return () => ctx.revert();
  }, [lang]);

  return (
    <footer ref={root} className="relative overflow-hidden bg-ink-900 text-white">
      <div className="mx-auto max-w-5xl px-5 py-16 text-center lg:px-8">
        <div className="mb-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <Link
            href="/"
            className="inline-flex items-center rounded-full border border-white/10 bg-white/5 px-4 py-2"
            aria-label={site.name}
          >
            <BrandMark />
          </Link>
          <nav className="hidden flex-wrap items-center justify-center rounded-full border border-white/10 bg-white/5 px-2 py-1.5 lg:flex">
            <Link href="/#features" className="rounded-full px-3 py-1.5 text-[13px] text-white/70 hover:text-white">{t.nav.features}</Link>
            <Link href="/#platforms" className="rounded-full px-3 py-1.5 text-[13px] text-white/70 hover:text-white">{t.nav.platforms}</Link>
            <Link href="/download" className="rounded-full px-3 py-1.5 text-[13px] text-white/70 hover:text-white">{t.nav.download}</Link>
            <a href={site.webApp} className="rounded-full px-3 py-1.5 text-[13px] text-white/70 hover:text-white">{t.footer.webApp}</a>
            <a href={site.login} className="rounded-full px-3 py-1.5 text-[13px] text-white/70 hover:text-white">{t.cta.login}</a>
          </nav>
        </div>

        <a
          href={site.register}
          className="mx-auto flex max-w-xl items-center justify-center gap-3 rounded-[28px] border border-white/10 bg-white/5 px-6 py-5 font-display text-2xl font-bold transition-colors hover:border-brand-400 hover:text-brand-300 sm:text-4xl"
        >
          <span className="size-2.5 rounded-full bg-brand-400" />
          {t.ctaSection.createAccount}
          <span className="size-2.5 rounded-full bg-brand-400" />
        </a>

        <p className="mx-auto mt-8 max-w-sm text-sm text-white/55">{t.footer.builtFor}</p>
        <div className="mt-10 flex items-center justify-between border-t border-white/10 pt-6 text-xs text-white/35">
          <span>© {new Date().getFullYear()} {site.name}. {t.footer.rights}</span>
          <button
            type="button"
            onClick={() => scrollTo(0)}
            className="flex size-10 items-center justify-center rounded-full border border-white/15 text-white hover:border-brand-400 hover:text-brand-300"
            aria-label={t.footer.toTop}
          >
            <ArrowUp className="h-4 w-4" />
          </button>
        </div>
      </div>
      <div
        data-giant
        aria-hidden
        className="pointer-events-none select-none px-4 pb-2 text-center font-display font-bold leading-none tracking-tight text-white/[0.07]"
        style={{ fontSize: 'clamp(3.5rem, 16vw, 11rem)' }}
      >
        {site.name}
      </div>
    </footer>
  );
}
