import { NextResponse, type NextRequest } from 'next/server'
import { crearClienteServidor } from '@/lib/supabase/server'

/**
 * Vuelta del magic link. Supabase manda el link de dos formas segun la version
 * de la plantilla de email: con token_hash + type, o con code (PKCE). Aceptamos
 * las dos para no depender de como quede configurado el proyecto.
 */
export async function GET(request: NextRequest) {
  const { searchParams, origin } = request.nextUrl
  const destino = searchParams.get('next') ?? '/'
  const supabase = await crearClienteServidor()

  const tokenHash = searchParams.get('token_hash')
  const tipo = searchParams.get('type')
  if (tokenHash && tipo) {
    const { error } = await supabase.auth.verifyOtp({
      type: tipo as 'magiclink' | 'email',
      token_hash: tokenHash,
    })
    if (!error) return NextResponse.redirect(`${origin}${destino}`)
  }

  const code = searchParams.get('code')
  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) return NextResponse.redirect(`${origin}${destino}`)
  }

  return NextResponse.redirect(`${origin}/entrar?error=link`)
}
