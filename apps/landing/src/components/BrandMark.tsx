import { site } from '@/config/site';

const [primary, ...rest] = site.name.split(/\s+/);
const secondary = rest.join(' ');

/** Elegant Amharic wordmark lockup used in header / footer. */
export default function BrandMark({
  className = '',
  size = 'md',
}: {
  className?: string;
  size?: 'md' | 'lg';
}) {
  return (
    <span
      className={`brand-mark ${size === 'lg' ? 'brand-mark--lg' : ''} ${className}`.trim()}
      aria-label={site.name}
    >
      <span className="brand-mark__primary">{primary}</span>
      {secondary ? (
        <>
          <span className="brand-mark__rule" aria-hidden />
          <span className="brand-mark__secondary">{secondary}</span>
        </>
      ) : null}
    </span>
  );
}
