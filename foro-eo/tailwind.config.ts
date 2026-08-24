import type { Config } from 'tailwindcss'

// El motivo visual es el iceberg de la metodologia: lo visible arriba de la
// linea de flotacion, el 80% que importa abajo. Los tokens salen de ahi.
const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        ink: '#08082A',    // fondo
        deep: '#101038',   // superficies
        shelf: '#181848',  // superficies elevadas
        line: '#2A2A63',   // divisores decorativos
        edge: '#6262A8',   // bordes de controles interactivos
        focus: '#7B87FF',  // foco de teclado
        bone: '#EFEDE6',   // texto principal
        mute: '#9A9AC4',   // texto secundario
        blue: '#4451F6',
        rose: '#FF2E63',
        coral: '#FF6B35',
        amber: '#F2B233',
        teal: '#17A98C',
      },
      fontFamily: {
        display: ['var(--font-fraunces)', 'Georgia', 'serif'],
        sans: ['var(--font-inter)', 'system-ui', 'sans-serif'],
        mono: ['var(--font-mono)', 'ui-monospace', 'monospace'],
      },
      borderRadius: { xl2: '1.25rem' },
    },
  },
  plugins: [],
}

export default config
