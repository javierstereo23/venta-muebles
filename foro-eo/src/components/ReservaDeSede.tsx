import {
  datosDeReserva,
  estaConfigurada,
  resumenDeLoQueSeManda,
  sedeDeclarada,
  urlPrecargada,
  type Participante,
} from '@/lib/sedes'
import { aValorFecha, hora } from '@/lib/fechas'
import type { Perfil, Reunion } from '@/lib/tipos-db'

interface Props {
  reunion: Reunion
  responsable: Perfil
  miembros: Perfil[]
}

/**
 * Cuando la reunión es en una sede con formulario propio, deja el formulario
 * precargado a un clic. No lo manda solo: se abre, se mira y se envía. Así, si
 * Google cambia algo, se ve en el momento y no el día del foro.
 */
export function ReservaDeSede({ reunion, responsable, miembros }: Props) {
  const sede = sedeDeclarada(reunion.location)
  if (!sede) return null

  if (!estaConfigurada(sede)) {
    return (
      <p className="mt-4 rounded-xl2 border border-dashed border-line p-4 text-sm text-mute">
        {sede.lugar} tiene formulario de reserva, pero todavía falta cargar a qué pregunta va cada
        dato. Hasta entonces hay que completarlo a mano.
      </p>
    )
  }

  const gente: Participante[] = miembros.map((m) => ({ full_name: m.full_name, email: m.email }))
  const datos = datosDeReserva(
    {
      fecha: aValorFecha(reunion.scheduled_at),
      desde: hora(reunion.scheduled_at),
      hasta: reunion.ends_at ? hora(reunion.ends_at) : '',
    },
    { full_name: responsable.full_name, email: responsable.email },
    gente,
  )
  const resumen = resumenDeLoQueSeManda(sede, datos)

  return (
    <div className="mt-4 rounded-xl2 border border-line bg-deep p-5">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="font-medium">Reserva de {sede.lugar}</p>
          <p className="mt-1 text-sm text-mute">
            El formulario se abre con todo cargado. Revisalo y mandalo.
          </p>
        </div>
        <a
          href={urlPrecargada(sede, datos)}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center justify-center rounded-lg bg-blue px-4 py-2.5 text-sm font-medium text-white hover:brightness-110"
        >
          Abrir el formulario de {sede.lugar} ↗
        </a>
      </div>

      <details className="mt-4">
        <summary className="cursor-pointer text-sm text-mute hover:text-bone">
          Qué se va a mandar ({resumen.length} {resumen.length === 1 ? 'dato' : 'datos'})
        </summary>
        <dl className="mt-3 space-y-2 border-t border-line pt-3 text-sm">
          {resumen.map((fila, i) => (
            <div key={`${fila.etiqueta}-${i}`} className="flex flex-wrap gap-x-3">
              <dt className="text-mute">{fila.etiqueta}:</dt>
              <dd className="whitespace-pre-line text-bone">{fila.valor}</dd>
            </div>
          ))}
        </dl>
        <p className="mt-3 text-xs leading-relaxed text-mute">
          Es lo único que sale del sistema. Nada del 5%, del Parking Lot ni de los puntajes.
        </p>
      </details>
    </div>
  )
}
