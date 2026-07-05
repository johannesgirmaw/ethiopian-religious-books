import type { SVGProps } from 'react';

type P = SVGProps<SVGSVGElement>;

export const Logo = (p: P) => (
  <svg viewBox="0 0 32 32" fill="none" {...p}>
    <rect width="32" height="32" rx="9" fill="url(#lg)" />
    <path
      d="M9 8.5h9.5c2.2 0 4 1.8 4 4v11c0-1.2-1-2.2-2.2-2.2H9V8.5Z"
      fill="#041820"
      opacity=".55"
    />
    <path
      d="M9 8.5h8.2c2.2 0 4 1.8 4 4v11c0-1.2-1-2.2-2.2-2.2H9V8.5Z"
      stroke="#eefdf7"
      strokeWidth="1.4"
      strokeLinejoin="round"
      fill="none"
    />
    <path d="M15 5.5v4M13 7.5h4" stroke="#f5a623" strokeWidth="1.4" strokeLinecap="round" />
    <defs>
      <linearGradient id="lg" x1="0" y1="0" x2="32" y2="32">
        <stop stopColor="#29b6e0" />
        <stop offset="1" stopColor="#14708f" />
      </linearGradient>
    </defs>
  </svg>
);

export const AndroidIcon = (p: P) => (
  <svg viewBox="0 0 24 24" fill="currentColor" {...p}>
    <path d="M17.6 9.48l1.84-3.18a.4.4 0 0 0-.7-.4l-1.87 3.23a11.4 11.4 0 0 0-9.74 0L5.26 5.9a.4.4 0 1 0-.7.4L6.4 9.48A10.8 10.8 0 0 0 1 18.24h22a10.8 10.8 0 0 0-5.4-8.76ZM7 15.25a1.1 1.1 0 1 1 0-2.2 1.1 1.1 0 0 1 0 2.2Zm10 0a1.1 1.1 0 1 1 0-2.2 1.1 1.1 0 0 1 0 2.2Z" />
  </svg>
);

export const AppleIcon = (p: P) => (
  <svg viewBox="0 0 24 24" fill="currentColor" {...p}>
    <path d="M16.36 12.9c.02 2.5 2.2 3.33 2.22 3.34-.02.06-.35 1.2-1.15 2.37-.69 1.02-1.4 2.03-2.53 2.05-1.1.02-1.46-.65-2.72-.65-1.27 0-1.66.63-2.7.67-1.09.04-1.92-1.1-2.62-2.11-1.42-2.07-2.51-5.85-1.05-8.4a4.06 4.06 0 0 1 3.43-2.1c1.07-.02 2.08.72 2.73.72.66 0 1.88-.89 3.17-.76.54.02 2.05.22 3.02 1.64-.08.05-1.8 1.06-1.78 3.16M14.3 4.6c.58-.7.97-1.67.86-2.64-.84.03-1.85.56-2.45 1.26-.53.62-1 1.6-.88 2.55.93.07 1.88-.47 2.47-1.17" />
  </svg>
);

export const WindowsIcon = (p: P) => (
  <svg viewBox="0 0 24 24" fill="currentColor" {...p}>
    <path d="M3 5.6 10.4 4.6v6.9H3V5.6Zm0 12.8 7.4 1v-6.8H3v5.8ZM11.3 4.47 21 3.1v8.4h-9.7V4.47Zm0 15.06L21 20.9v-8.4h-9.7v7.03Z" />
  </svg>
);

export const LinuxIcon = (p: P) => (
  <svg viewBox="0 0 24 24" fill="currentColor" {...p}>
    <path d="M12 2c-2.3 0-3.6 2-3.5 4.3.06 1.36.06 2.2-.4 3.2-.5 1.1-1.7 2.3-2.3 3.9-.5 1.3-.2 2 .2 2.3.3.9-.2 1.5-.5 2.2-.3.8.2 1.4 1 1.4.7 0 1.6-.4 2.5-.4.5 0 1 .2 1.5.2s1-.2 1.5-.2c.9 0 1.8.4 2.5.4.8 0 1.3-.6 1-1.4-.3-.7-.8-1.3-.5-2.2.4-.3.7-1-.2-2.3-.6-1.6-1.8-2.8-2.3-3.9-.46-1-.46-1.84-.4-3.2C15.6 4 14.3 2 12 2Zm-1.4 4c.4 0 .7.4.7.9s-.3.9-.7.9-.7-.4-.7-.9.3-.9.7-.9Zm2.8 0c.4 0 .7.4.7.9s-.3.9-.7.9-.7-.4-.7-.9.3-.9.7-.9Zm-1.4 2.5c.7 0 1.6.5 1.6.9 0 .3-.9.8-1.6.8s-1.6-.5-1.6-.8c0-.4.9-.9 1.6-.9Z" />
  </svg>
);

export const GlobeIcon = (p: P) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" {...p}>
    <circle cx="12" cy="12" r="9" />
    <path d="M3 12h18M12 3c2.5 2.5 3.8 6 3.8 9S14.5 18.5 12 21c-2.5-2.5-3.8-6-3.8-9S9.5 5.5 12 3Z" />
  </svg>
);

export const ArrowRight = (p: P) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" {...p}>
    <path d="M5 12h14M13 6l6 6-6 6" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const DownloadIcon = (p: P) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" {...p}>
    <path d="M12 3v12m0 0 4-4m-4 4-4-4M5 21h14" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const Check = (p: P) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" {...p}>
    <path d="M5 13l4 4L19 7" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const platformIcon: Record<string, (p: P) => JSX.Element> = {
  android: AndroidIcon,
  macos: AppleIcon,
  windows: WindowsIcon,
  linux: LinuxIcon,
};
