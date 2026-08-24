import { redirect } from 'next/navigation'
import { crearClienteServidor } from '@/lib/supabase/server'
import type { Perfil } from '@/lib/tipos-db'

/**
 * Perfil de quien esta logueado. Devuelve null si no hay sesion, o si hay
 * sesion pero no hay perfil: eso ultimo solo puede pasar si a alguien le
 * revocaron el lugar en el foro, y en ese caso no ve nada.
 */
export async function perfilActual(): Promise<Perfil | null> {
  const supabase = await crearClienteServidor()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return null

  const { data } = await supabase.from('profiles').select('*').eq('id', user.id).maybeSingle()
  return data ?? null
}

export async function exigirPerfil(): Promise<Perfil> {
  const perfil = await perfilActual()
  if (!perfil) redirect('/entrar')
  return perfil
}

/** URL firmada y de vida corta. El bucket es privado: no hay links permanentes. */
export async function urlFirmadaAvatar(ruta: string | null): Promise<string | null> {
  if (!ruta) return null
  const supabase = await crearClienteServidor()
  const { data } = await supabase.storage.from('avatars').createSignedUrl(ruta, 60 * 60)
  return data?.signedUrl ?? null
}
