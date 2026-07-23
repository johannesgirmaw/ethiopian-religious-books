'use client';

import Link from 'next/link';
import { site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import { Logo } from './icons';

export default function Footer() {
  const { t } = useLang();
  return (
    <footer className="border-t border-white/10 py-12">
      <div className="container-px flex flex-col gap-8 md:flex-row md:items-center md:justify-between">
        <div className="flex items-center gap-3">
          <Logo className="h-9 w-9" />
          <div className="font-semibold text-white">{site.name}</div>
        </div>

        <nav className="flex flex-wrap gap-x-7 gap-y-3 text-sm text-slate-300">
          <Link href="/#features" className="hover:text-white">{t.nav.features}</Link>
          <Link href="/#platforms" className="hover:text-white">{t.nav.platforms}</Link>
          <Link href="/download" className="hover:text-white">{t.nav.download}</Link>
          <a href={site.webApp} className="hover:text-white">{t.footer.webApp}</a>
          <a href={site.login} className="hover:text-white">{t.cta.login}</a>
        </nav>
      </div>
      <div className="container-px mt-8 flex flex-col gap-2 border-t border-white/5 pt-6 text-xs text-slate-500 sm:flex-row sm:items-center sm:justify-between">
        <p>© {new Date().getFullYear()} {site.name}. {t.footer.rights}</p>
        <p>{t.footer.builtFor}</p>
      </div>
    </footer>
  );
}
