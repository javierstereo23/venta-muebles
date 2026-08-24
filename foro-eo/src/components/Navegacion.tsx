import Link from 'next/link'
import { ETIQUETA_ROL } from '@/lib/roles'
import type { Perfil } from '@/lib/tipos-db'

const ENLACES = [
  { href: '/', texto: 'Inicio' },
  { href: '/miembros', texto: 'Miembros' },
  { href: '/perfil', texto: 'Mi perfil' },
]

export function Navegacion({ perfil }: { perfil: Perfil }) {
  return (
    <header className="border-b border-line">
      <nav
        aria-label="Principal"
        className="mx-auto flex max-w-5xl flex-wrap items-center gap-x-6 gap-y-3 px-6 py-4"
      >
        <Link href="/" className="font-display text-lg">
          Foro EO
        </Link>
        <ul className="flex flex-1 flex-wrap items-center gap-x-5 gap-y-2 text-sm">
          {ENLACES.map((enlace) => (
            <li key={enlace.href}>
              <Link href={enlace.href} className="text-mute hover:text-bone">
                {enlace.texto}
              </Link>
            </li>
          ))}
        </ul>
        <span className="font-mono text-xs uppercase tracking-widest text-mute">
          {ETIQUETA_ROL[perfil.role]}
        </span>
        <form action="/auth/salir" method="post">
          <button type="submit" className="text-sm text-mute hover:text-bone">
            Salir
          </button>
        </form>
      </nav>
    </header>
  )
}
