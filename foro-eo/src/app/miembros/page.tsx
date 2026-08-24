import type { Metadata } from 'next'
import { exigirPerfil, urlFirmadaAvatar } from '@/lib/sesion'
import { crearClienteServidor } from '@/lib/supabase/server'
import { Navegacion } from '@/components/Navegacion'
import { Avatar } from '@/components/Avatar'
import { ETIQUETA_ROL } from '@/lib/roles'
import type { Perfil } from '@/lib/tipos-db'

export const metadata: Metadata = { title: 'Miembros · Foro EO' }

const ORDEN_ROL = { moderator: 0, moderator_elect: 1, moderator_outgoing: 2, member: 3 } as const

function fechaLarga(iso: string | null): string | null {
  if (!iso) return null
  return new Date(`${iso}T12:00:00`).toLocaleDateString('es-AR', {
    month: 'long',
    year: 'numeric',
  })
}

export default async function PaginaMiembros() {
  const perfil = await exigirPerfil()
  const supabase = await crearClienteServidor()

  const { data } = await supabase.from('profiles').select('*').order('full_name')
  const miembros: Perfil[] = (data ?? []).sort(
    (a, b) => ORDEN_ROL[a.role] - ORDEN_ROL[b.role] || a.full_name.localeCompare(b.full_name, 'es'),
  )

  const fotos = await Promise.all(miembros.map((m) => urlFirmadaAvatar(m.avatar_path)))

  return (
    <>
      <Navegacion perfil={perfil} />
      <main className="mx-auto max-w-5xl px-6 py-12">
        <h1 className="font-display text-3xl">El foro</h1>
        <p className="mt-2 text-sm text-mute">
          {miembros.length} {miembros.length === 1 ? 'miembro' : 'miembros'}.
        </p>

        <ul className="mt-8 grid gap-4 sm:grid-cols-2">
          {miembros.map((miembro, i) => {
            const desde = fechaLarga(miembro.joined_forum_on)
            return (
              <li
                key={miembro.id}
                className="flex items-center gap-4 rounded-xl2 border border-line bg-deep p-4"
              >
                <Avatar nombre={miembro.full_name} url={fotos[i] ?? null} />
                <div className="min-w-0">
                  <p className="truncate font-medium">{miembro.full_name}</p>
                  <p className="font-mono text-xs uppercase tracking-widest text-mute">
                    {ETIQUETA_ROL[miembro.role]}
                  </p>
                  {desde ? <p className="mt-1 text-xs text-mute">En el foro desde {desde}</p> : null}
                </div>
              </li>
            )
          })}
        </ul>
      </main>
    </>
  )
}
