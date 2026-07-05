'use client';

import { createContext, useContext, useEffect, useState } from 'react';
import { dict, type Dict, type Lang } from './translations';

type Ctx = { lang: Lang; setLang: (l: Lang) => void; toggle: () => void; t: Dict };

const LanguageContext = createContext<Ctx | null>(null);

const STORAGE_KEY = 'fm-lang';

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLangState] = useState<Lang>('en');

  // Load saved preference (or browser language) on mount.
  useEffect(() => {
    let initial: Lang | null = null;
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved === 'en' || saved === 'am') initial = saved;
    } catch {}
    if (!initial && typeof navigator !== 'undefined' && navigator.language?.startsWith('am')) {
      initial = 'am';
    }
    if (initial) setLangState(initial);
  }, []);

  // Reflect language on <html> and persist.
  useEffect(() => {
    document.documentElement.lang = lang;
    try {
      localStorage.setItem(STORAGE_KEY, lang);
    } catch {}
  }, [lang]);

  const setLang = (l: Lang) => setLangState(l);
  const toggle = () => setLangState((p) => (p === 'en' ? 'am' : 'en'));

  return (
    <LanguageContext.Provider value={{ lang, setLang, toggle, t: dict[lang] }}>
      {children}
    </LanguageContext.Provider>
  );
}

export function useLang(): Ctx {
  const ctx = useContext(LanguageContext);
  if (!ctx) throw new Error('useLang must be used within LanguageProvider');
  return ctx;
}

// Small helper for "{token}" interpolation.
export function fill(template: string, vars: Record<string, string>): string {
  return template.replace(/\{(\w+)\}/g, (_, k) => vars[k] ?? `{${k}}`);
}
