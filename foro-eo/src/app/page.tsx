import Link from 'next/link'
import { exigirPerfil, urlFirmadaAvatar } from '@/lib/sesion'
import { crearClienteServidor } from '@/lib/supabase/server'
import { Navegacion } from '@/components/Navegacion'
import { Avatar } from '@/components/Avatar'
import { Cornerstones } from '@/components/Cornerstones'
import { CuentaRegresiva } from '@/components/CuentaRegresiva'
import { LineaDeFlotacion } from '@/components/LineaDeFlotacion'
import { ReservaDeSede } from '@/components/ReservaDeSede'
import { FormularioFecha } from './reunion/FormularioFecha'
import { aValorFecha, diaYFecha, hora, rangoHorario, ZONA } from '@/lib/fechas'
import { esModerador } from '@/lib/roles'
import type { Perfil, Reunion, ValorForo } from '@/lib/tipos-db'

const SEIS_HORAS = 6 * 60 * 60 * 1000

function fechaDelRetreat(iso: string): string {
  return new Date(`${iso}T12:00:00`).toLocaleDateString('es-AR', {
    timeZone: ZONA,
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  })
}

export default async function PaginaInicio() {
  const perfil = await exigirPerfil()
  const supabase = await crearClienteServidor()

  // Una reunión que arrancó hace un rato sigue siendo "la próxima" hasta que
  // termina: si no, el inicio se queda en blanco justo durante el foro.
  const desde = new Date(Date.now() - SEIS_HORAS).toISOString()

  const [{ data: foro }, { data: proxima }, { data: gente }, { data: valores }] = await Promise.all([
    supabase.from('forums').select('*').maybeSingle(),
    supabase
      .from('meetings')
      .select('*')
      .gte('scheduled_at', desde)
      .order('scheduled_at')
      .limit(1)
      .maybeSingle(),
    supabase.from('profiles').select('*').order('full_name'),
    supabase.from('forum_values').select('*').order('position'),
  ])

  const miembros: Perfil[] = gente ?? []
  const fotos = await Promise.all(miembros.map((m) => urlFirmadaAvatar(m.avatar_path)))
  const reunion: Reunion | null = proxima ?? null
  const listaValores: ValorForo[] = valores ?? []
  const puedeFijar = esModerador(perfil.role)

  return (
    <>
      <Navegacion perfil={perfil} />
      <main className="mx-auto max-w-5xl px-6 pb-24 pt-14">
        <p className="font-mono text-xs uppercase tracking-[0.2em] text-mute">
          {foro?.name ?? 'Foro EO'}
        </p>
        <h1 className="mt-5 max-w-3xl font-display text-3xl leading-[1.15] sm:text-5xl">
          {foro?.purpose ??
            'Que cada foro sea una experiencia que te transforme y te eleve: como persona, como emprendedor, como pareja, en cada rol que te importa.'}
        </h1>

        <section aria-labelledby="proxima" className="mt-16">
          <h2 id="proxima" className="font-mono text-xs uppercase tracking-[0.2em] text-mute">
            Próxima reunión
          </h2>

          {reunion ? (
            <div className="mt-5 rounded-xl2 border border-line bg-deep p-6 sm:p-8">
              <div className="flex flex-wrap items-end justify-between gap-8">
                <div>
                  <p className="font-display text-2xl leading-tight first-letter:uppercase sm:text-3xl">
                    {diaYFecha(reunion.scheduled_at)}
                  </p>
                  <p className="mt-2 font-mono text-sm text-mute">
                    {rangoHorario(reunion.scheduled_at, reunion.ends_at)}
                    {reunion.location ? ` · ${reunion.location}` : ''}
                  </p>
                </div>
                <CuentaRegresiva hasta={reunion.scheduled_at} />
              </div>
            </div>
          ) : (
            <p className="mt-5 rounded-xl2 border border-dashed border-line p-6 text-sm text-mute">
              Todavía no hay fecha para el próximo foro.
            </p>
          )}

          {puedeFijar && reunion ? (
            <ReservaDeSede reunion={reunion} responsable={perfil} miembros={miembros} />
          ) : null}

          {puedeFijar ? (
            <FormularioFecha
              reunionId={reunion?.id}
              fecha={reunion ? aValorFecha(reunion.scheduled_at) : undefined}
              desde={reunion ? hora(reunion.scheduled_at) : undefined}
              hasta={reunion?.ends_at ? hora(reunion.ends_at) : undefined}
              lugar={reunion?.location ?? undefined}
            />
          ) : null}

          {foro?.next_retreat_on ? (
            <p className="mt-6 text-sm text-mute">
              Retreat del año:{' '}
              <span className="font-mono text-bone">{fechaDelRetreat(foro.next_retreat_on)}</span>
            </p>
          ) : null}
        </section>

        <section aria-labelledby="elforo" className="mt-16">
          <h2 id="elforo" className="font-mono text-xs uppercase tracking-[0.2em] text-mute">
            El foro
          </h2>
          <ul className="mt-5 flex flex-wrap gap-x-8 gap-y-5">
            {miembros.map((miembro, i) => (
              <li key={miembro.id} className="flex items-center gap-3">
                <Avatar nombre={miembro.full_name} url={fotos[i] ?? null} tamaño={44} />
                <span className="text-sm">{miembro.full_name}</span>
              </li>
            ))}
          </ul>
        </section>

        <LineaDeFlotacion texto="el 80% que no se ve" />

        <Cornerstones />

        <section aria-labelledby="valores" className="mt-16">
          <div className="flex flex-wrap items-baseline justify-between gap-4">
            <h2 id="valores" className="font-display text-2xl">
              Nuestros valores
            </h2>
            <Link href="/valores" className="text-sm text-mute hover:text-bone">
              Editarlos →
            </Link>
          </div>

          {listaValores.length > 0 ? (
            <dl className="mt-6 grid gap-x-10 gap-y-6 sm:grid-cols-2">
              {listaValores.map((valor) => (
                <div key={valor.id}>
                  <dt className="font-display text-lg text-bone">{valor.label}</dt>
                  {valor.body ? (
                    <dd className="mt-1 text-sm leading-relaxed text-mute">{valor.body}</dd>
                  ) : null}
                </div>
              ))}
            </dl>
          ) : (
            <p className="mt-6 rounded-xl2 border border-dashed border-line p-6 text-sm text-mute">
              Todavía no los escribieron.{' '}
              <Link href="/valores" className="text-bone underline underline-offset-4">
                Empezar la lista
              </Link>
              .
            </p>
          )}
        </section>
      </main>
    </>
  )
}
