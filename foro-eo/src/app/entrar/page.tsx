import type { Metadata } from 'next'
import { FormularioIngreso } from './FormularioIngreso'

export const metadata: Metadata = { title: 'Entrar · Foro EO' }

export default function PaginaEntrar() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-8 px-6 py-16">
      <div className="space-y-3">
        <p className="font-mono text-xs uppercase tracking-[0.2em] text-mute">Foro EO Buenos Aires</p>
        <h1 className="font-display text-4xl leading-tight">Lo que se comparte acá, queda acá.</h1>
        <p className="text-sm leading-relaxed text-mute">
          Entrás con tu email. Te mandamos un link de un solo uso: no hay contraseña que perder ni
          que compartir.
        </p>
      </div>

      <FormularioIngreso />

      <p className="border-t border-line pt-6 text-xs leading-relaxed text-mute">
        El acceso está limitado a los ocho miembros del foro. Si tu email no está en la lista, no vas
        a recibir ningún link.
      </p>
    </main>
  )
}
