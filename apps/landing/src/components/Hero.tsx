'use client';

import { site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import {
  BookIcon,
  GlobeIcon,
  HighlightIcon,
  OfflineIcon,
  PlanIcon,
  SearchIcon,
} from './icons';
import PrimaryDownload from './PrimaryDownload';
import BookStack from './BookStack';
import Marquee from './Marquee';

const FLOATING = [
  { Icon: BookIcon, bg: 'bg-brand-400 text-white', rotate: '-16deg', className: 'left-[2%] top-[6%]', delay: '0s' },
  { Icon: OfflineIcon, bg: 'bg-gold-400 text-ink-900', rotate: '-8deg', className: 'bottom-[18%] left-[10%]', delay: '-1.4s' },
  { Icon: SearchIcon, bg: 'bg-brand-500 text-white', rotate: '6deg', className: 'bottom-0 left-1/2 -translate-x-1/2', delay: '-2.6s' },
  { Icon: HighlightIcon, bg: 'bg-brand-400 text-white', rotate: '12deg', className: 'bottom-[16%] right-[8%]', delay: '-0.8s' },
  { Icon: PlanIcon, bg: 'bg-gold-400 text-ink-900', rotate: '18deg', className: 'right-[1%] top-[4%]', delay: '-2s' },
] as const;

export default function Hero() {
  const { t } = useLang();
  const marquee = [
    t.hero.cards.bible,
    t.hero.cards.praise,
    t.hero.cards.synax,
    'Web',
    'Android',
    'macOS',
    'Windows',
    'Linux',
  ];

  return (
    <section className="relative flex min-h-[92vh] flex-col overflow-hidden bg-white pt-[calc(5.5rem+env(safe-area-inset-top))] lg:pt-24">
      <div className="hero-glow pointer-events-none absolute inset-0" />
      <div
        aria-hidden
        className="pointer-events-none absolute left-1/2 top-[42%] size-[720px] -translate-x-1/2 -translate-y-1/2 rounded-full border border-ink-900/[0.05]"
      />
      <div
        aria-hidden
        className="pointer-events-none absolute left-1/2 top-[42%] size-[520px] -translate-x-1/2 -translate-y-1/2 rounded-full border border-ink-900/[0.05]"
      />

      <div className="relative mx-auto flex w-full max-w-5xl flex-1 flex-col items-center px-5 pb-8 pt-10 text-center lg:pt-16">
        <p className="mb-5 inline-flex items-center gap-2 rounded-full border border-ink-900/10 bg-white px-3 py-1 text-xs font-medium text-ink-900/70 shadow-sm animate-fade-up">
          <span className="size-1.5 rounded-full bg-brand-400" />
          {t.hero.eyebrow}
        </p>

        <h1
          className="display-heading max-w-4xl text-ink-900 animate-fade-up"
          style={{ animationDelay: '80ms' }}
        >
          {t.hero.titleA}{' '}
          <span className="highlight">{t.hero.titleB}</span>
        </h1>

        <p
          className="mt-6 max-w-xl text-base text-slate-500 sm:text-lg animate-fade-up"
          style={{ animationDelay: '160ms' }}
        >
          {t.hero.subtitle}
        </p>

        <div
          className="mt-8 flex flex-col items-center gap-3 sm:flex-row animate-fade-up"
          style={{ animationDelay: '240ms' }}
        >
          <PrimaryDownload />
          <a href={site.webApp} className="btn-pill border border-ink-900/10 bg-white text-ink-800 hover:border-brand-400 hover:text-brand-600">
            <GlobeIcon className="h-4 w-4 text-brand-500" /> {t.cta.openWebApp}
          </a>
        </div>

        <div className="relative mt-10 hidden h-[300px] w-full lg:block">
          {FLOATING.map((card) => (
            <div key={card.rotate} className={`absolute ${card.className}`}>
              <div className="animate-float-y" style={{ animationDelay: card.delay }}>
                <div
                  className="flex size-[7.5rem] items-center justify-center rounded-[28px] bg-white shadow-[0_22px_50px_rgb(4_24_32/0.12)]"
                  style={{ transform: `rotate(${card.rotate})` }}
                >
                  <span className={`flex size-14 items-center justify-center rounded-2xl ${card.bg}`}>
                    <card.Icon className="size-7" />
                  </span>
                </div>
              </div>
            </div>
          ))}
          <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
            <div className="pointer-events-auto scale-90">
              <BookStack
                books={[
                  { title: 'መጽሐፍ ቅዱስ', subtitle: t.hero.cards.bible },
                  { title: 'ውዳሴ ማርያም', subtitle: t.hero.cards.praise },
                  { title: 'ስንክሳር', subtitle: t.hero.cards.synax },
                ]}
              />
            </div>
          </div>
        </div>

        <div className="mt-10 w-full max-w-lg lg:hidden">
          <BookStack
            books={[
              { title: 'መጽሐፍ ቅዱስ', subtitle: t.hero.cards.bible },
              { title: 'ውዳሴ ማርያም', subtitle: t.hero.cards.praise },
              { title: 'ስንክሳር', subtitle: t.hero.cards.synax },
            ]}
          />
          <div className="mt-2 flex justify-center gap-3">
            {FLOATING.slice(0, 3).map((card) => (
              <div
                key={card.rotate}
                className="flex size-[4.5rem] items-center justify-center rounded-[22px] bg-white shadow-[0_16px_40px_rgb(4_24_32/0.1)]"
              >
                <span className={`flex size-11 items-center justify-center rounded-2xl ${card.bg}`}>
                  <card.Icon className="size-5" />
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="relative border-t border-ink-900/5 py-3">
        <Marquee items={marquee} />
      </div>
    </section>
  );
}
