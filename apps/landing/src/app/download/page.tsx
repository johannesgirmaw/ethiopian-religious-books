import type { Metadata } from 'next';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import DownloadGrid from '@/components/DownloadGrid';
import { site } from '@/config/site';
import { GlobeIcon } from '@/components/icons';

export const metadata: Metadata = {
  title: 'Download & Install',
  description:
    'Install Felege Metsahft on Android, macOS, Windows and Linux — or open the web app instantly. Step-by-step installation guides for every platform.',
  alternates: { canonical: '/download' },
};

export default function DownloadPage() {
  return (
    <>
      <Header />
      <main className="pt-32">
        <section className="container-px text-center">
          <span className="eyebrow">Install the app</span>
          <h1 className="mx-auto mt-5 max-w-3xl font-display text-4xl font-semibold text-white sm:text-5xl">
            Get <span className="gold-text">{site.name}</span> on your device
          </h1>
          <p className="mx-auto mt-5 max-w-2xl text-lg text-slate-300">
            Choose your platform below. Prefer not to install? You can use everything right in your
            browser.
          </p>
          <div className="mt-8 flex justify-center">
            <a href={site.webApp} className="btn-ghost">
              <GlobeIcon className="h-5 w-5" /> Open the web app instead
            </a>
          </div>
        </section>

        <DownloadGrid />

        <section className="container-px pb-24">
          <div className="glass rounded-2xl p-6 text-center text-sm text-slate-400">
            Having trouble installing? Email us at{' '}
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
