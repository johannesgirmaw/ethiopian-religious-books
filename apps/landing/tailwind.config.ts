import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // Matches the app design tokens (lib/design/app_tokens.dart):
        // primary #29B6E0, deep #14708F, mid #5CCDEC, secondary #1E9BC2.
        brand: {
          50: '#ecfaff',
          100: '#d0f2fd',
          200: '#a6e7fb',
          300: '#5ccdec',
          400: '#29b6e0',
          500: '#1e9bc2',
          600: '#14708f',
          700: '#105c76',
          800: '#0a3a4a',
          900: '#072c39',
          950: '#041820',
        },
        // App accent (notification orange #F5A623 → #E08E00).
        gold: {
          400: '#f7b74d',
          500: '#f5a623',
          600: '#e08e00',
        },
        // Dark background ramp from the app's dark hero gradient
        // [#14708F, #0A3A4A, #041820].
        ink: {
          900: '#041820',
          800: '#082935',
          700: '#0a3a4a',
        },
      },
      fontFamily: {
        sans: ['var(--font-sans)', 'var(--font-ethiopic)', 'system-ui', 'sans-serif'],
        display: ['var(--font-display)', 'var(--font-ethiopic)', 'Georgia', 'serif'],
      },
      keyframes: {
        'fade-up': {
          '0%': { opacity: '0', transform: 'translateY(16px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        float: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-10px)' },
        },
        shimmer: {
          '0%': { backgroundPosition: '-200% 0' },
          '100%': { backgroundPosition: '200% 0' },
        },
      },
      animation: {
        'fade-up': 'fade-up 0.7s cubic-bezier(0.22,1,0.36,1) both',
        float: 'float 6s ease-in-out infinite',
        shimmer: 'shimmer 3s linear infinite',
      },
    },
  },
  plugins: [],
};

export default config;
