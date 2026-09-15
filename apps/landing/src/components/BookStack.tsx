'use client';

import { useCallback, useRef, type MouseEvent } from 'react';

type Book = { title: string; subtitle: string };

export default function BookStack({ books }: { books: Book[] }) {
  const rig = useRef<HTMLDivElement>(null);

  const onMove = useCallback((e: MouseEvent<HTMLDivElement>) => {
    const el = rig.current;
    const stage = e.currentTarget;
    if (!el) return;
    const r = stage.getBoundingClientRect();
    const x = (e.clientX - r.left) / r.width - 0.5;
    const y = (e.clientY - r.top) / r.height - 0.5;
    el.style.setProperty('--rx', `${(8 - y * 8).toFixed(2)}deg`);
    el.style.setProperty('--ry', `${(-16 + x * 10).toFixed(2)}deg`);
  }, []);

  const onLeave = useCallback(() => {
    const el = rig.current;
    if (!el) return;
    el.style.setProperty('--rx', '8deg');
    el.style.setProperty('--ry', '-16deg');
  }, []);

  const variants = ['', 'book--mid', 'book--right'];
  const offsets = [
    { x: -6.1, y: 1.6, z: -56, rot: -22 },
    { x: 0, y: -0.4, z: 18, rot: -3 },
    { x: 6.2, y: 1.4, z: -42, rot: 20 },
  ];

  return (
    <div
      className="book-stage relative mx-auto flex h-[22rem] w-full max-w-xl items-center justify-center sm:h-[24rem]"
      onMouseMove={onMove}
      onMouseLeave={onLeave}
    >
      <div
        aria-hidden
        className="pointer-events-none absolute h-48 w-48 rounded-full bg-brand-400/20 blur-3xl animate-float"
      />
      <div ref={rig} className="book-rig relative h-64 w-full max-w-md sm:h-72">
        {books.slice(0, 3).map((book, i) => {
          const o = offsets[i];
          const front = i === 1;
          return (
            <article
              key={book.title}
              className={`book absolute left-1/2 top-1/2 ${variants[i]}`}
              style={{
                transform: `translate3d(calc(-50% + ${o.x}rem), calc(-50% + ${o.y}rem), ${o.z}px) rotateY(${o.rot}deg)`,
                zIndex: front ? 3 : 2,
              }}
            >
              <div className="book__spine" />
              <div className="book__pages" />
              <div className="book__face flex flex-col justify-between p-5 text-left">
                <div className="h-1 w-8 rounded-full bg-white/70" />
                {front ? (
                  <div>
                    <div className="font-ethiopic text-lg font-semibold leading-snug text-white">
                      {book.title}
                    </div>
                    <div className="mt-1.5 text-xs font-medium text-white/85">{book.subtitle}</div>
                  </div>
                ) : (
                  <div className="space-y-2">
                    <div className="h-1.5 w-16 rounded-full bg-white/45" />
                    <div className="h-1.5 w-10 rounded-full bg-white/30" />
                  </div>
                )}
              </div>
            </article>
          );
        })}
      </div>
    </div>
  );
}
