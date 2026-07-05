'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { platforms, type Platform } from '@/config/site';
import { platformIcon, DownloadIcon } from './icons';

function detect(): Platform['id'] | null {
  if (typeof navigator === 'undefined') return null;
  const ua = navigator.userAgent.toLowerCase();
  if (/android/.test(ua)) return 'android';
  if (/iphone|ipad|ipod/.test(ua)) return 'macos'; // iOS users → point to macOS/web for now
  if (/win/.test(ua)) return 'windows';
  if (/mac/.test(ua)) return 'macos';
  if (/linux/.test(ua)) return 'linux';
  return null;
}

export default function PrimaryDownload() {
  const [id, setId] = useState<Platform['id'] | null>(null);
  useEffect(() => setId(detect()), []);

  const p = platforms.find((x) => x.id === id);

  if (!p || p.comingSoon) {
    return (
      <Link href="/download" className="btn-primary text-base">
        <DownloadIcon className="h-5 w-5" /> Download the app
      </Link>
    );
  }

  const Icon = platformIcon[p.id];
  return (
    <div className="flex flex-col items-center gap-2 sm:items-start">
      <a href={p.url} className="btn-primary text-base" download>
        <Icon className="h-5 w-5" /> Download for {p.os}
      </a>
      <Link href="/download" className="text-xs text-slate-400 hover:text-white">
        or choose another platform →
      </Link>
    </div>
  );
}
