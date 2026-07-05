import type { Metadata } from 'next';
import DownloadPageBody from '@/components/DownloadPageBody';

export const metadata: Metadata = {
  title: 'Download & Install',
  description:
    'Install Felege Metsahft on Android, macOS, Windows and Linux — or open the web app instantly. Step-by-step installation guides for every platform.',
  alternates: { canonical: '/download' },
};

export default function DownloadPage() {
  return <DownloadPageBody />;
}
