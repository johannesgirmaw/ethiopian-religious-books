'use client';

import { useLang } from '@/i18n/LanguageProvider';
import { SearchIcon } from './icons';

export default function ReaderScreen() {
  const { t } = useLang();
  const books = [t.hero.cards.bible, t.hero.cards.praise, t.hero.cards.synax];

  return (
    <div
      data-reader
      className="reader-screen pointer-events-none relative w-[min(92vw,52rem)] overflow-hidden rounded-[28px] bg-ink-900 text-white shadow-[0_40px_90px_-28px_rgb(4_24_32/0.55)]"
    >
      <div className="flex items-center justify-between border-b border-white/10 px-4 py-3 sm:px-5">
        <div className="flex items-center gap-2">
          <img src="/logo-mark.png" alt="" className="h-6 w-6 object-contain" />
          <span className="font-ethiopic text-sm font-semibold tracking-wide">{t.reader.today}</span>
        </div>
        <div className="flex items-center gap-2 text-white/50">
          <SearchIcon className="h-4 w-4" />
          <span className="hidden h-6 w-6 rounded-full bg-brand-400/90 sm:block" />
        </div>
      </div>

      <div className="grid grid-cols-[4.5rem_1fr] sm:grid-cols-[11rem_1fr]">
        <aside className="space-y-2 border-r border-white/10 p-3">
          {books.map((label, i) => (
            <div
              key={label}
              data-ui
              className={`rounded-xl px-2 py-2 text-[10px] leading-tight sm:px-3 sm:text-xs ${
                i === 1 ? 'bg-white/10 text-white' : 'text-white/45'
              }`}
            >
              <span className="mb-1 block h-1 w-6 rounded-full bg-brand-400/80" />
              <span className="hidden sm:block">{label}</span>
            </div>
          ))}
        </aside>

        <div className="relative min-h-[16rem] p-4 pb-12 sm:min-h-[18.5rem] sm:p-6 sm:pb-14">
          <p data-ui className="font-ethiopic text-lg font-semibold text-white sm:text-2xl">
            ውዳሴ ማርያም
          </p>
          <p data-ui className="mt-1 text-[11px] uppercase tracking-[0.2em] text-brand-300">
            {t.hero.cards.praise}
          </p>

          <div className="mt-5 space-y-2.5">
            <p data-ui className="max-w-md text-sm leading-relaxed text-white/55 sm:text-[15px]">
              {t.reader.lead}
            </p>
            <p
              data-ui
              className="max-w-lg rounded-xl bg-gold-500/20 px-3 py-2 text-sm leading-relaxed text-gold-400 sm:text-[15px]"
            >
              {t.reader.verse}
            </p>
            <p data-ui className="max-w-md text-sm leading-relaxed text-white/45 sm:text-[15px]">
              {t.reader.tail}
            </p>
          </div>

          <div data-ui className="absolute bottom-4 left-4 right-4 sm:left-6 sm:right-6">
            <div className="mb-1.5 flex justify-between text-[10px] uppercase tracking-[0.18em] text-white/35">
              <span>{t.reader.progress}</span>
              <span>64%</span>
            </div>
            <div className="h-1.5 overflow-hidden rounded-full bg-white/10">
              <div data-progress className="h-full w-[64%] rounded-full bg-brand-400" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
