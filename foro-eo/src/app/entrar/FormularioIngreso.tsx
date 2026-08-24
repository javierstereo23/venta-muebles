'use client'

import { useState } from 'react'
import { crearClienteNavegador } from '@/lib/supabase/client'
import { Boton } from '@/components/Boton'
import { Campo } from '@/components/Campo'

type Estado = 'inicial' | 'enviando' | 'enviado' | 'error'

export function FormularioIngreso() {
  const [email, setEmail] = useState('')
  const [estado, setEstado] = useState<Estado>('inicial')

  async function enviar(evento: React.FormEvent<HTMLFormElement>) {
    evento.preventDefault()
    setEstado('enviando')

    const supabase = crearClienteNavegador()
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`,
      },
    })

    // Un email fuera de la lista blanca lo rechaza la base al crear el usuario.
    // No distinguimos ese caso en pantalla: decir "ese email no existe" seria
    // contar quien esta en el foro y quien no.
    if (error) {
      console.warn('[entrar] el alta no prospero')
    }
    setEstado('enviado')
  }

  if (estado === 'enviado') {
    return (
      <div
        role="status"
        className="rounded-xl2 border border-edge bg-shelf p-6 text-sm leading-relaxed"
      >
        <p className="font-medium text-bone">Listo.</p>
        <p className="mt-2 text-mute">
          Si <span className="font-mono text-bone">{email.trim()}</span> pertenece al foro, en un
          minuto te llega el link. Abrilo desde este mismo dispositivo.
        </p>
        <Boton
          variante="fantasma"
          className="mt-4 px-0"
          onClick={() => {
            setEstado('inicial')
            setEmail('')
          }}
        >
          Probar con otro email
        </Boton>
      </div>
    )
  }

  return (
    <form onSubmit={enviar} className="flex flex-col gap-4">
      <Campo
        etiqueta="Tu email"
        name="email"
        type="email"
        autoComplete="email"
        inputMode="email"
        required
        placeholder="vos@tuempresa.com"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
      />
      <Boton type="submit" disabled={estado === 'enviando'}>
        {estado === 'enviando' ? 'Mandando el link…' : 'Mandame el link'}
      </Boton>
    </form>
  )
}
