'use server'

import { revalidatePath } from 'next/cache'
import { crearClienteServidor } from '@/lib/supabase/server'

export interface EstadoGuardado {
  mensaje: string | null
  error: string | null
}

export async function guardarPerfil(
  _anterior: EstadoGuardado,
  datos: FormData,
): Promise<EstadoGuardado> {
  const supabase = await crearClienteServidor()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return { mensaje: null, error: 'Se cerró la sesión. Volvé a entrar.' }

  const nombre = String(datos.get('full_name') ?? '').trim()
  if (nombre.length < 2) {
    return { mensaje: null, error: 'Escribí tu nombre y apellido.' }
  }

  const desdeCrudo = String(datos.get('joined_forum_on') ?? '').trim()
  if (desdeCrudo && Number.isNaN(Date.parse(desdeCrudo))) {
    return { mensaje: null, error: 'Esa fecha de ingreso no es válida.' }
  }

  // La policy solo deja tocar la propia fila, y el trigger de la base impide
  // cambiar rol, foro o email aunque se manipule el formulario.
  const { error } = await supabase
    .from('profiles')
    .update({ full_name: nombre, joined_forum_on: desdeCrudo || null })
    .eq('id', user.id)

  if (error) return { mensaje: null, error: 'No se pudo guardar. Probá de nuevo.' }

  revalidatePath('/perfil')
  revalidatePath('/miembros')
  return { mensaje: 'Listo, guardado.', error: null }
}
