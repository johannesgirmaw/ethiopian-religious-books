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
      <main>
        <section className="relative overflow-hidden bg-white pt-[calc(5.5rem+env(safe-area-inset-top))] pb-12 lg:pt-28 lg:pb-14">
          <div className="hero-glow pointer-events-none absolute inset-0" />
          <div className="container-px relative text-center">
            <p className="section-label justify-center">{t.download.eyebrow}</p>
            <h1 className="mx-auto mt-3 max-w-3xl display-heading text-ink-900" style={{ fontSize: 'clamp(2rem, 4vw, 3.25rem)' }}>
              {before}
              <span className="highlight">{site.name}</span>
              {after}
            </h1>
            <p className="mx-auto mt-5 max-w-2xl text-lg text-slate-500">{t.download.sub}</p>
            <div className="mt-8 flex justify-center">
              <a href={site.webApp} className="btn-pill border border-ink-900/10 bg-white text-ink-800 hover:border-brand-400">
                <GlobeIcon className="h-5 w-5 text-brand-500" /> {t.download.openInstead}
              </a>
            </div>
          </div>
        </section>

        <div className="bg-slate-50">
          <DownloadGrid />
        </div>

        <section className="container-px py-16">
          <div className="soft-card p-6 text-center text-sm text-slate-500">
            {t.download.help}{' '}
            <a href={`mailto:${site.email}`} className="font-medium text-brand-600 hover:text-brand-500">
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
