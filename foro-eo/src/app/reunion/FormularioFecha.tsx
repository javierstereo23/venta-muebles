'use client'

import { useActionState } from 'react'
import { fijarFecha, type EstadoFecha } from './acciones'
import { Boton } from '@/components/Boton'
import { Campo } from '@/components/Campo'

const INICIAL: EstadoFecha = { mensaje: null, error: null }

interface Props {
  reunionId?: string
  fecha?: string
  desde?: string
  hasta?: string
  lugar?: string
}

export function FormularioFecha({ reunionId, fecha, desde, hasta, lugar }: Props) {
  const [estado, accion, pendiente] = useActionState(fijarFecha, INICIAL)

  return (
    <details className="mt-6 rounded-xl2 border border-line bg-deep">
      <summary className="cursor-pointer px-5 py-3 text-sm text-mute hover:text-bone">
        {reunionId ? 'Cambiar la fecha' : 'Fijar la fecha del próximo foro'}
      </summary>
      <form action={accion} className="flex flex-col gap-4 border-t border-line p-5">
        {reunionId ? <input type="hidden" name="reunion" value={reunionId} /> : null}
        <div className="grid gap-4 sm:grid-cols-3">
          <Campo etiqueta="Fecha" name="fecha" type="date" required defaultValue={fecha} />
          <Campo etiqueta="Desde" name="desde" type="time" required defaultValue={desde ?? '16:00'} />
          <Campo etiqueta="Hasta" name="hasta" type="time" defaultValue={hasta ?? '20:00'} />
        </div>
        <Campo etiqueta="Lugar" name="lugar" defaultValue={lugar} placeholder="Hit Polo" />
        <p className="text-xs leading-relaxed text-mute">
          La reunión queda con la agenda base cargada y los horarios ya calculados. Si hay una
          votación de fechas abierta, queda sin efecto: lo votado no se borra.
        </p>
        <div className="flex items-center gap-4">
          <Boton type="submit" disabled={pendiente}>
            {pendiente ? 'Guardando…' : 'Fijar la fecha'}
          </Boton>
          {estado.mensaje ? (
            <p role="status" className="text-sm text-teal">
              {estado.mensaje}
            </p>
          ) : null}
          {estado.error ? (
            <p role="alert" className="text-sm text-rose">
              {estado.error}
            </p>
          ) : null}
        </div>
      </form>
    </details>
  )
}
