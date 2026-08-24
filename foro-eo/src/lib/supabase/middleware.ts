import { NextResponse, type NextRequest } from 'next/server'
import { createServerClient, type CookieOptions } from '@supabase/ssr'
import type { Database } from '@/lib/tipos-db'

const RUTAS_ABIERTAS = ['/entrar', '/auth']

export async function actualizarSesion(request: NextRequest) {
  let respuesta = NextResponse.next({ request })

  const supabase = createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (galletas: { name: string; value: string; options: CookieOptions }[]) => {
          galletas.forEach(({ name, value }) => request.cookies.set(name, value))
          respuesta = NextResponse.next({ request })
          galletas.forEach(({ name, value, options }) => respuesta.cookies.set(name, value, options))
        },
      },
    },
  )

  const {
    data: { user },
  } = await supabase.auth.getUser()

  const ruta = request.nextUrl.pathname
  const esAbierta = RUTAS_ABIERTAS.some((r) => ruta === r || ruta.startsWith(`${r}/`))

  if (!user && !esAbierta) {
    const destino = request.nextUrl.clone()
    destino.pathname = '/entrar'
    destino.search = ''
    return NextResponse.redirect(destino)
  }

  if (user && ruta === '/entrar') {
    const destino = request.nextUrl.clone()
    destino.pathname = '/'
    destino.search = ''
    return NextResponse.redirect(destino)
  }

  return respuesta
}
