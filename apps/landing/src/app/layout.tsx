import type { Metadata } from 'next';
import { Inter, Fraunces, Noto_Sans_Ethiopic } from 'next/font/google';
import { site } from '@/config/site';
import { LanguageProvider } from '@/i18n/LanguageProvider';
import './globals.css';

const inter = Inter({ subsets: ['latin'], variable: '--font-sans', display: 'swap' });
const fraunces = Fraunces({
  subsets: ['latin'],
  variable: '--font-display',
  display: 'swap',
  weight: ['400', '500', '600', '700'],
});
const ethiopic = Noto_Sans_Ethiopic({
  subsets: ['ethiopic'],
  variable: '--font-ethiopic',
  display: 'swap',
  weight: ['400', '500', '600', '700'],
});

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: {
    default: `${site.name} — ${site.tagline}`,
    template: `%s · ${site.name}`,
  },
  description: site.description,
  keywords: [
    'Ethiopian Orthodox books',
    'Tewahedo',
    'Amharic Bible',
    'Ethiopian religious books',
    'Geez',
    'Ethiopian Bible app',
    'ፈለገ መጻሕፍት',
    'digital reader',
  ],
  authors: [{ name: site.name }],
  alternates: { canonical: '/' },
  openGraph: {
    type: 'website',
    url: site.url,
    title: `${site.name} — ${site.tagline}`,
    description: site.description,
    siteName: site.name,
    locale: 'en_US',
  },
  twitter: {
    card: 'summary_large_image',
    title: `${site.name} — ${site.tagline}`,
    description: site.description,
  },
  robots: { index: true, follow: true },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: site.name,
    alternateName: site.nameLatin,
    applicationCategory: 'BookApplication',
    operatingSystem: 'Android, macOS, Windows, Linux, Web',
    description: site.description,
    url: site.url,
    offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
  };

  return (
    <html lang="en" className={`${inter.variable} ${fraunces.variable} ${ethiopic.variable}`}>
      <body>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
        <LanguageProvider>{children}</LanguageProvider>
      </body>
    </html>
  );
}
