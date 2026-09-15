'use client';

export default function Marquee({
  items,
  className = '',
}: {
  items: string[];
  className?: string;
}) {
  const text = items.join('  ·  ');
  return (
    <div className={`marquee-mask overflow-hidden ${className}`.trim()}>
      <div className="flex w-max animate-marquee items-center gap-8">
        {[0, 1].map((copy) => (
          <span
            key={copy}
            className="whitespace-nowrap font-mono text-xs font-medium uppercase tracking-[0.28em] text-brand-500"
            aria-hidden={copy === 1}
          >
            {text}
            {'  ·  '}
            {text}
          </span>
        ))}
      </div>
    </div>
  );
}
