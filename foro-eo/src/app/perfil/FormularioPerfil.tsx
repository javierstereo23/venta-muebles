'use client'

import { useActionState } from 'react'
import { guardarPerfil, type EstadoGuardado } from './acciones'
import { Boton } from '@/components/Boton'
import { Campo } from '@/components/Campo'
import type { Perfil } from '@/lib/tipos-db'

const INICIAL: EstadoGuardado = { mensaje: null, error: null }

export function FormularioPerfil({ perfil }: { perfil: Perfil }) {
  const [estado, accion, pendiente] = useActionState(guardarPerfil, INICIAL)

  return (
    <form action={accion} className="flex max-w-md flex-col gap-5">
      <Campo
        etiqueta="Nombre y apellido"
        name="full_name"
        defaultValue={perfil.full_name}
        required
        autoComplete="name"
      />
      <Campo
        etiqueta="En el foro desde"
        name="joined_forum_on"
        type="date"
        defaultValue={perfil.joined_forum_on ?? ''}
        ayuda="Aproximado alcanza."
      />
      <Campo
        etiqueta="Email"
        name="email"
        defaultValue={perfil.email}
        disabled
        readOnly
        ayuda="Es con el que entrás. Lo cambia el moderador."
        className="opacity-70"
      />

      <div className="flex items-center gap-4">
        <Boton type="submit" disabled={pendiente}>
          {pendiente ? 'Guardando…' : 'Guardar'}
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
  )
}
