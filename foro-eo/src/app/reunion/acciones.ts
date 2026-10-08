'use server'

import { revalidatePath } from 'next/cache'
import { crearClienteServidor } from '@/lib/supabase/server'
import { perfilActual } from '@/lib/sesion'
import { aInstante } from '@/lib/fechas'
import { esModerador } from '@/lib/roles'

export interface EstadoFecha {
  mensaje: string | null
  error: string | null
}

/**
 * Fija la fecha del próximo foro sin esperar a que cierre la votación. La base
 * vuelve a verificar que sea el moderador: esto es solo la primera barrera.
 */
export async function fijarFecha(_anterior: EstadoFecha, datos: FormData): Promise<EstadoFecha> {
  const perfil = await perfilActual()
  if (!perfil) return { mensaje: null, error: 'Se cerró la sesión. Volvé a entrar.' }
  if (!esModerador(perfil.role)) {
    return { mensaje: null, error: 'Solo el moderador fija la fecha del foro.' }
  }

  const fecha = String(datos.get('fecha') ?? '').trim()
  const desde = String(datos.get('desde') ?? '').trim()
  const hasta = String(datos.get('hasta') ?? '').trim()
  const lugar = String(datos.get('lugar') ?? '').trim()
  const reunion = String(datos.get('reunion') ?? '').trim()

  if (!fecha || !desde) return { mensaje: null, error: 'Falta la fecha o la hora de inicio.' }
  if (hasta && hasta <= desde) {
    return { mensaje: null, error: 'La reunión no puede terminar antes de empezar.' }
  }

  const supabase = await crearClienteServidor()
  const { error } = await supabase.rpc('schedule_meeting', {
    p_forum: perfil.forum_id,
    p_starts_at: aInstante(fecha, desde),
    p_ends_at: hasta ? aInstante(fecha, hasta) : null,
    p_location: lugar || null,
    p_meeting: reunion || null,
  })

  if (error) return { mensaje: null, error: 'No se pudo fijar la fecha. Probá de nuevo.' }

  revalidatePath('/')
  return {
    mensaje: 'Fecha fijada. Si había una votación abierta, quedó sin efecto.',
    error: null,
  }
}
