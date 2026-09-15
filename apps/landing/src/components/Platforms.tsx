'use client';

import { useLayoutEffect, useRef } from 'react';
import Link from 'next/link';
import { platforms, site } from '@/config/site';
import { useLang } from '@/i18n/LanguageProvider';
import { platformIcon, GlobeIcon, DownloadIcon, ArrowRight } from './icons';
import WordReveal from './WordReveal';
import { gsap, registerGsap, prefersReducedMotion } from '@/lib/gsap';

export default function Platforms() {
  const { t, lang } = useLang();
  const root = useRef<HTMLElement>(null);

  useLayoutEffect(() => {
    registerGsap();
    const el = root.current;
    if (!el) return;
    const ctx = gsap.context(() => {
      if (prefersReducedMotion()) return;
      const mm = gsap.matchMedia();

      mm.add('(min-width: 1024px)', () => {
        const track = el.querySelector<HTMLElement>('[data-track]');
        const pin = el.querySelector<HTMLElement>('[data-pin-platforms]');
        if (!track || !pin) return;
        const distance = () => Math.max(0, track.scrollWidth - window.innerWidth + 80);
        gsap.to(track, {
          x: () => -distance(),
          ease: 'none',
          scrollTrigger: {
            trigger: pin,
            start: 'top top',
            end: () => `+=${distance() + window.innerHeight * 0.35}`,
            pin: true,
            scrub: 1,
            anticipatePin: 1,
            invalidateOnRefresh: true,
          },
        });
      });

      mm.add('(max-width: 1023px)', () => {
        gsap.from('[data-platform]', {
          y: 36,
          opacity: 0,
          filter: 'blur(8px)',
          stagger: 0.08,
          duration: 0.7,
          ease: 'power3.out',
          scrollTrigger: { trigger: el, start: 'top 78%' },
        });
      });
    }, el);
    return () => ctx.revert();
  }, [lang]);

  return (
    <section id="platforms" ref={root} className="bg-white">
      <div data-pin-platforms className="lg:flex lg:h-[100svh] lg:flex-col lg:justify-center">
        <div className="container-px py-16 lg:py-10">
          <div className="mx-auto max-w-3xl text-center">
            <p className="section-label">{t.platforms.eyebrow}</p>
            <WordReveal
              as="h2"
              text={t.platforms.heading}
              className="font-display text-3xl font-bold tracking-tight text-ink-900 sm:text-5xl sm:leading-[1.1]"
            />
            <p className="mx-auto mt-4 max-w-xl text-slate-500">{t.platforms.body}</p>
            <div className="mt-8 flex flex-wrap justify-center gap-3">
              <a href={site.webApp} className="btn-pill border border-ink-900/10 bg-white text-ink-800 hover:border-brand-400">
                <GlobeIcon className="h-5 w-5 text-brand-500" /> {t.platforms.openWebApp}
              </a>
              <Link href="/download" className="btn-pill bg-brand-400 text-white shadow-lg shadow-brand-400/25 hover:bg-brand-500">
                <DownloadIcon className="h-5 w-5" /> {t.platforms.allDownloads}
              </Link>
            </div>
          </div>
        </div>

        <div className="overflow-hidden pb-16 lg:pb-10">
          <div data-track className="flex w-full flex-col gap-5 px-5 sm:px-8 md:grid md:grid-cols-2 lg:flex lg:w-max lg:flex-row lg:px-[12vw]">
            <a
              href={site.webApp}
              data-platform
              className="platform-panel group flex w-full shrink-0 flex-col justify-between rounded-[28px] bg-ink-900 p-7 text-white lg:w-[min(84vw,28rem)]"
            >
              <span className="flex size-12 items-center justify-center rounded-2xl bg-white/10 text-brand-300">
                <GlobeIcon className="h-7 w-7" />
              </span>
              <div className="mt-10">
                <div className="font-display text-2xl font-semibold">Web</div>
                    <p className="mt-2 line-clamp-3 max-w-xs text-sm text-white/60">{t.platforms.openWebApp}</p>
                <span className="mt-6 inline-flex items-center gap-1 text-sm font-medium text-brand-300">
                  {t.platforms.openWebApp} <ArrowRight className="h-4 w-4" />
                </span>
              </div>
            </a>
            {platforms.map((p) => {
              const Icon = platformIcon[p.id];
              const note = t.plat[p.id].note;
              const inner = (
                <>
                  <span className="flex size-12 items-center justify-center rounded-2xl bg-brand-50 text-brand-500">
                    <Icon className="h-7 w-7" />
                  </span>
                  <div className="mt-10">
                    <div className="font-display text-2xl font-semibold text-ink-900">{p.os}</div>
                    <p className="mt-2 text-sm text-slate-500">
                      {p.comingSoon ? t.download.comingSoon : `.${p.ext.toLowerCase()} · ${note}`}
                    </p>
                    {!p.comingSoon && (
                      <span className="mt-6 inline-flex items-center gap-1 text-sm font-medium text-brand-600">
                        {t.nav.download} <ArrowRight className="h-4 w-4" />
                      </span>
                    )}
                  </div>
                </>
              );
              const cls =
                'platform-panel group flex w-full shrink-0 flex-col rounded-[28px] bg-slate-50 p-7 transition duration-300 hover:-translate-y-1 hover:bg-white hover:shadow-[0_18px_40px_rgb(4_24_32/0.08)] lg:w-[min(84vw,28rem)]';
              return p.comingSoon ? (
                <div key={p.id} data-platform className={`${cls} opacity-60`}>{inner}</div>
              ) : (
                <a key={p.id} href={p.url} download data-platform className={cls}>{inner}</a>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}
