import type { Metadata, Viewport } from 'next'
import { Fraunces, Inter, JetBrains_Mono } from 'next/font/google'
import './globals.css'

const fraunces = Fraunces({ subsets: ['latin'], variable: '--font-fraunces', display: 'swap' })
const inter = Inter({ subsets: ['latin'], variable: '--font-inter', display: 'swap' })
const mono = JetBrains_Mono({ subsets: ['latin'], variable: '--font-mono', display: 'swap' })

export const metadata: Metadata = {
  title: 'Foro EO',
  description: 'Plataforma del Foro EO Buenos Aires.',
  robots: { index: false, follow: false },
}

export const viewport: Viewport = {
  themeColor: '#08082A',
  colorScheme: 'dark',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es" className={`${fraunces.variable} ${inter.variable} ${mono.variable}`}>
      <body className="min-h-dvh bg-ink font-sans text-bone">{children}</body>
    </html>
  )
}
