'use client';

import Header from '@/components/Header';
import Footer from '@/components/Footer';
import DownloadGrid from '@/components/DownloadGrid';
import { site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import { GlobeIcon } from '@/components/icons';

export default function DownloadPageBody() {
  const { t } = useLang();
  const [before, after] = t.download.title.split('{name}');
  return (
    <>
      <Header />
      <main className="pt-32">
        <section className="container-px text-center">
          <span className="eyebrow">{t.download.eyebrow}</span>
          <h1 className="mx-auto mt-5 max-w-3xl font-display text-4xl font-semibold text-white sm:text-5xl">
            {before}
            <span className="gold-text">{site.name}</span>
            {after}
          </h1>
          <p className="mx-auto mt-5 max-w-2xl text-lg text-slate-300">{t.download.sub}</p>
          <div className="mt-8 flex justify-center">
            <a href={site.webApp} className="btn-ghost">
              <GlobeIcon className="h-5 w-5" /> {t.download.openInstead}
            </a>
          </div>
        </section>

        <DownloadGrid />

        <section className="container-px pb-24">
          <div className="glass rounded-2xl p-6 text-center text-sm text-slate-400">
            {t.download.help}{' '}
            <a href={`mailto:${site.email}`} className="text-brand-300 hover:text-brand-200">
              {site.email}
            </a>
            .
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
