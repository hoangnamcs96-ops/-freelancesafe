/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        ink: '#0B1F44',
        navy: { DEFAULT: '#0E2A5C', deep: '#08183A' },
        brand: { DEFAULT: '#1F6FEB', dark: '#1859C4', soft: '#E8F0FE' },
        canvas: '#F4F7FC',
        line: '#E3EAF5',
        muted: '#51617F',
        subtle: '#7A89A5',
        ok: '#1A8047',
        warn: '#9A5B05',
        bad: '#B3261E',
      },
      fontFamily: {
        display: ['"Space Grotesk"', 'sans-serif'],
        sans: ['"DM Sans"', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'Menlo', 'monospace'],
      },
      boxShadow: {
        card: '0 1px 2px rgba(11,31,68,0.04), 0 8px 24px -12px rgba(11,31,68,0.12)',
      },
    },
  },
  plugins: [],
}
