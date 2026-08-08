import { site } from '@/config/site';

const [primary, ...rest] = site.name.split(/\s+/);
const secondary = rest.join(' ');

/** Figurative mark + Amharic wordmark lockup used in header / footer. */
export default function BrandMark({
  className = '',
  size = 'md',
}: {
  className?: string;
  size?: 'md' | 'lg';
}) {
  const lg = size === 'lg';
  return (
    <span
      className={`brand-lockup ${lg ? 'brand-lockup--lg' : ''} ${className}`.trim()}
      aria-label={site.name}
    >
      {/* Decorative: the lockup already carries an aria-label. Plain <img>
          because output:'export' runs with images.unoptimized. */}
      <img src="/logo-mark.png" alt="" aria-hidden className="brand-lockup__mark" />
      <span className={`brand-mark ${lg ? 'brand-mark--lg' : ''}`.trim()}>
        <span className="brand-mark__primary">{primary}</span>
        {secondary ? (
          <>
            <span className="brand-mark__rule" aria-hidden />
            <span className="brand-mark__secondary">{secondary}</span>
          </>
        ) : null}
      </span>
    </span>
  );
}
