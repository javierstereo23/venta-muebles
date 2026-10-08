'use server'

import { revalidatePath } from 'next/cache'
import { crearClienteServidor } from '@/lib/supabase/server'
import { perfilActual } from '@/lib/sesion'

// Los valores son del grupo, no del moderador: cualquier miembro los edita.
// La RLS deja escribir solo dentro del propio foro.

async function refrescar() {
  revalidatePath('/')
  revalidatePath('/valores')
}

export async function agregarValor(datos: FormData): Promise<void> {
  const perfil = await perfilActual()
  if (!perfil) return

  const label = String(datos.get('label') ?? '').trim()
  if (!label) return
  const body = String(datos.get('body') ?? '').trim()

  const supabase = await crearClienteServidor()
  const { count } = await supabase
    .from('forum_values')
    .select('id', { count: 'exact', head: true })
    .eq('forum_id', perfil.forum_id)

  await supabase.from('forum_values').insert({
    forum_id: perfil.forum_id,
    label,
    body: body || null,
    position: count ?? 0,
  })

  await refrescar()
}

export async function actualizarValor(datos: FormData): Promise<void> {
  const perfil = await perfilActual()
  if (!perfil) return

  const id = String(datos.get('id') ?? '')
  const label = String(datos.get('label') ?? '').trim()
  if (!id || !label) return
  const body = String(datos.get('body') ?? '').trim()

  const supabase = await crearClienteServidor()
  await supabase.from('forum_values').update({ label, body: body || null }).eq('id', id)

  await refrescar()
}

export async function borrarValor(datos: FormData): Promise<void> {
  const perfil = await perfilActual()
  if (!perfil) return

  const id = String(datos.get('id') ?? '')
  if (!id) return

  const supabase = await crearClienteServidor()
  await supabase.from('forum_values').delete().eq('id', id)

  await refrescar()
}
