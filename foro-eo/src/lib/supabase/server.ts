import { cookies } from 'next/headers'
import { createServerClient, type CookieOptions } from '@supabase/ssr'
import type { Database } from '@/lib/tipos-db'

/**
 * Cliente de servidor. Usa siempre la anon key: toda lectura y escritura pasa
 * por RLS con la identidad de quien esta logueado. En ningun lugar del proyecto
 * se usa la service_role key.
 */
export async function crearClienteServidor() {
  const almacen = await cookies()

  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => almacen.getAll(),
        setAll: (galletas: { name: string; value: string; options: CookieOptions }[]) => {
          try {
            galletas.forEach(({ name, value, options }) => almacen.set(name, value, options))
          } catch {
            // Los Server Components no pueden escribir cookies; el middleware
            // ya refresco la sesion antes de llegar aca.
          }
        },
      },
    },
  )
}
