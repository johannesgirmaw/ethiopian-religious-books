import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#eefdf7',
          100: '#d5f9ea',
          200: '#aef1d7',
          300: '#77e3bf',
          400: '#3ecda1',
          500: '#18b287',
          600: '#0d9070',
          700: '#0d735c',
          800: '#0f5b4a',
          900: '#0e4b3e',
          950: '#052a23',
        },
        gold: {
          400: '#e6c667',
          500: '#d4af37',
          600: '#b8912a',
        },
        ink: {
          900: '#07120f',
          800: '#0b1a16',
          700: '#0f241e',
        },
      },
      fontFamily: {
        sans: ['var(--font-sans)', 'system-ui', 'sans-serif'],
        display: ['var(--font-display)', 'Georgia', 'serif'],
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
