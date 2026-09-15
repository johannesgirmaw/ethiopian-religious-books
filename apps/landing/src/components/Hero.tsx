'use client';

import { useLayoutEffect, useRef } from 'react';
import { site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import {
  BookIcon,
  GlobeIcon,
  HighlightIcon,
  OfflineIcon,
  PlanIcon,
  SearchIcon,
  ChevronDown,
} from './icons';
import PrimaryDownload from './PrimaryDownload';
import BookStack from './BookStack';
import ReaderScreen from './ReaderScreen';
import Marquee from './Marquee';
import { gsap, registerGsap, prefersReducedMotion } from '@/lib/gsap';
import { scrollTo } from '@/lib/scroll';

const FLOATING = [
  { Icon: BookIcon, bg: 'bg-brand-400 text-white', rotate: '-16deg', className: 'left-[4%] top-[10%]', delay: '0s' },
  { Icon: OfflineIcon, bg: 'bg-gold-400 text-ink-900', rotate: '-8deg', className: 'bottom-[22%] left-[8%]', delay: '-1.4s' },
  { Icon: SearchIcon, bg: 'bg-brand-500 text-white', rotate: '6deg', className: 'bottom-[4%] left-1/2 -translate-x-1/2', delay: '-2.6s' },
  { Icon: HighlightIcon, bg: 'bg-brand-400 text-white', rotate: '12deg', className: 'bottom-[20%] right-[7%]', delay: '-0.8s' },
  { Icon: PlanIcon, bg: 'bg-gold-400 text-ink-900', rotate: '18deg', className: 'right-[3%] top-[8%]', delay: '-2s' },
] as const;

function splitWords(text: string) {
  return text.split(/\s+/).filter(Boolean);
}

export default function Hero() {
  const { t, lang } = useLang();
  const root = useRef<HTMLElement>(null);
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
  const books = [
    { title: 'መጽሐፍ ቅዱስ', subtitle: t.hero.cards.bible },
    { title: 'ውዳሴ ማርያም', subtitle: t.hero.cards.praise },
    { title: 'ስንክሳር', subtitle: t.hero.cards.synax },
  ];

  useLayoutEffect(() => {
    registerGsap();
    const el = root.current;
    if (!el) return;

    const ctx = gsap.context(() => {
      const words = el.querySelectorAll<HTMLElement>('[data-word]');
      const copy = el.querySelector<HTMLElement>('[data-copy]');
      const stage = el.querySelector<HTMLElement>('[data-stage]');
      const screen = el.querySelector<HTMLElement>('[data-reader]');
      const booksWrap = el.querySelector<HTMLElement>('[data-books]');
      const icons = gsap.utils.toArray<HTMLElement>('[data-float]');
      const ui = el.querySelectorAll<HTMLElement>('[data-ui]');
      const progress = el.querySelector<HTMLElement>('[data-progress]');
      const scrollHint = el.querySelector<HTMLElement>('[data-scroll-hint]');

      if (prefersReducedMotion()) {
        gsap.set([words, copy, stage, screen, booksWrap, icons, ui, scrollHint], { clearProps: 'all' });
        return;
      }

      const mm = gsap.matchMedia();

      mm.add('(min-width: 1024px)', () => {
        gsap.set(screen, {
          opacity: 0,
          scale: 0.2,
          rotateX: 58,
          y: 140,
          filter: 'blur(12px)',
          transformOrigin: '50% 80%',
        });
        gsap.set(ui, { opacity: 0, y: 10 });
        gsap.set(progress, { scaleX: 0, transformOrigin: 'left center' });

        gsap.from(words, {
          opacity: 0.18,
          y: 18,
          filter: 'blur(8px)',
          stagger: 0.028,
          duration: 0.75,
          ease: 'power3.out',
        });
        gsap.from('[data-highlight]', {
          opacity: 0.2,
          filter: 'blur(8px)',
          duration: 0.75,
          ease: 'power3.out',
        });
        gsap.from('[data-cta]', { opacity: 0, y: 14, duration: 0.55, delay: 0.16, ease: 'power3.out' });
        gsap.from(icons, { opacity: 0, scale: 0.72, stagger: 0.05, duration: 0.65, delay: 0.08, ease: 'power3.out' });

        const pin = el.querySelector('[data-pin]');
        const tl = gsap.timeline({
          defaults: { ease: 'none' },
          scrollTrigger: {
            trigger: pin,
            start: 'top top',
            end: '+=260%',
            pin: true,
            scrub: 1.05,
            anticipatePin: 1,
          },
        });

        tl.to(screen, {
          opacity: 1,
          scale: 0.58,
          rotateX: 18,
          y: 64,
          filter: 'blur(0px)',
          duration: 0.55,
        }, 0.2);

        tl.to(copy, { opacity: 0, y: -56, filter: 'blur(8px)', pointerEvents: 'none', duration: 0.4 }, 0.58);
        tl.to(scrollHint, { opacity: 0, duration: 0.2 }, 0.58);
        tl.to(icons, {
          opacity: 0,
          y: (i) => (i % 2 === 0 ? -48 : 36),
          x: (i) => (i < 2 ? -30 : 30),
          duration: 0.4,
        }, 0.6);

        tl.to(booksWrap, { opacity: 0, y: 70, scale: 0.86, duration: 0.45 }, 0.68);
        tl.to(stage, { y: -48, duration: 0.45 }, 0.68);
        tl.to(screen, { scale: 1.12, rotateX: 0, y: -20, duration: 0.7 }, 0.7);
        tl.to(ui, { opacity: 1, y: 0, stagger: 0.05, duration: 0.35 }, 0.95);
        tl.to(progress, { scaleX: 1, duration: 0.35 }, 1.05);
      });

      mm.add('(max-width: 1023px)', () => {
        gsap.from(words, {
          opacity: 0.15,
          y: 18,
          filter: 'blur(8px)',
          stagger: 0.03,
          duration: 0.7,
          ease: 'power3.out',
        });
        gsap.from('[data-highlight]', {
          opacity: 0.2,
          filter: 'blur(8px)',
          duration: 0.7,
          ease: 'power3.out',
        });
        gsap.from('[data-cta]', { opacity: 0, y: 16, duration: 0.6, delay: 0.15, ease: 'power3.out' });
        gsap.from(screen, {
          opacity: 0,
          y: 48,
          rotateX: 16,
          duration: 1,
          delay: 0.2,
          ease: 'power3.out',
        });
        gsap.from(ui, { opacity: 0, y: 8, stagger: 0.05, duration: 0.5, delay: 0.45, ease: 'power2.out' });
      });
    }, el);

    return () => ctx.revert();
  }, [lang]);

  return (
    <section ref={root} className="relative bg-white">
      <div data-pin className="relative flex min-h-[100svh] flex-col pt-[calc(5.5rem+env(safe-area-inset-top))] lg:pt-24">
        <div className="hero-glow pointer-events-none absolute inset-0" />
        <div
          aria-hidden
          className="pointer-events-none absolute left-1/2 top-[46%] size-[720px] -translate-x-1/2 -translate-y-1/2 rounded-full border border-ink-900/[0.05]"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute left-1/2 top-[46%] size-[520px] -translate-x-1/2 -translate-y-1/2 rounded-full border border-ink-900/[0.05]"
        />

        <div
          data-copy
          className="relative z-20 mx-auto flex w-full max-w-5xl flex-col items-center px-5 pt-8 text-center lg:pt-8"
        >
          <p className="mb-5 inline-flex items-center gap-2 rounded-full border border-ink-900/10 bg-white px-3 py-1 text-xs font-medium text-ink-900/70 shadow-sm">
            <span className="size-1.5 rounded-full bg-brand-400" />
            {t.hero.eyebrow}
          </p>

          <h1 className="display-heading max-w-4xl text-ink-900">
            {splitWords(t.hero.titleA).map((word, i) => (
              <span key={`a-${i}`} data-word className="mr-[0.22em] inline-block will-change-[opacity,filter,transform]">
                {word}
              </span>
            ))}
            <span data-highlight className="highlight">
              {t.hero.titleB}
            </span>
          </h1>

          <p className="mt-6 max-w-xl text-base text-slate-500 sm:text-lg">
            {splitWords(t.hero.subtitle).map((word, i) => (
              <span key={`s-${i}`} data-word className="mr-[0.28em] inline-block will-change-[opacity,filter,transform]">
                {word}
              </span>
            ))}
          </p>

          <div data-cta className="mt-8 flex flex-col items-center gap-3 sm:flex-row">
            <PrimaryDownload />
            <a href={site.webApp} className="btn-pill border border-ink-900/10 bg-white text-ink-800 hover:border-brand-400 hover:text-brand-600">
              <GlobeIcon className="h-4 w-4 text-brand-500" /> {t.cta.openWebApp}
            </a>
          </div>
        </div>

        <div data-stage className="relative z-10 mx-auto mt-2 w-full flex-1 lg:flex lg:items-center">
          <div className="pointer-events-none absolute inset-0 hidden lg:block">
            {FLOATING.map((card) => (
              <div key={card.rotate} data-float className={`absolute ${card.className}`}>
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
          </div>

          <div className="relative mx-auto hidden h-[min(42vh,24rem)] w-full max-w-5xl lg:block" style={{ perspective: '1600px' }}>
            <div data-books className="absolute inset-0 flex items-center justify-center">
              <BookStack books={books} tilt={false} />
            </div>
            <div className="absolute inset-0 z-20 flex items-center justify-center">
              <ReaderScreen />
            </div>
          </div>

          <div className="relative mx-auto mt-6 w-full max-w-lg px-5 pb-6 lg:hidden">
            <BookStack books={books} />
            <div className="relative z-10 -mt-16 scale-[0.92]">
              <ReaderScreen />
            </div>
            <div className="mt-4 flex justify-center gap-3">
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

        <button
          type="button"
          data-scroll-hint
          onClick={() => scrollTo('#experience')}
          className="absolute bottom-16 left-5 z-30 hidden size-11 items-center justify-center rounded-full border border-ink-900/10 bg-white text-ink-900 shadow-sm transition hover:border-brand-400 lg:flex"
          aria-label={t.hero.scroll}
        >
          <ChevronDown className="h-5 w-5" />
        </button>
      </div>

      <div className="relative z-10 border-t border-ink-900/5 py-3">
        <Marquee items={marquee} />
      </div>
    </section>
  );
}
