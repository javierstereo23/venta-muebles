'use client'

import { useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import { crearClienteNavegador } from '@/lib/supabase/client'
import { Avatar } from '@/components/Avatar'
import { Boton } from '@/components/Boton'

const MAXIMO_BYTES = 5 * 1024 * 1024
const TIPOS = ['image/jpeg', 'image/png', 'image/webp']

interface Props {
  nombre: string
  urlActual: string | null
  idUsuario: string
}

export function SubidaFoto({ nombre, urlActual, idUsuario }: Props) {
  const router = useRouter()
  const entrada = useRef<HTMLInputElement>(null)
  const [vista, setVista] = useState(urlActual)
  const [error, setError] = useState<string | null>(null)
  const [subiendo, setSubiendo] = useState(false)

  async function subir(archivo: File) {
    setError(null)
    if (!TIPOS.includes(archivo.type)) return setError('Tiene que ser una imagen JPG, PNG o WEBP.')
    if (archivo.size > MAXIMO_BYTES) return setError('La foto no puede pasar de 5 MB.')

    setSubiendo(true)
    const supabase = crearClienteNavegador()
    // La ruta arranca con el id de quien sube: la policy del bucket no deja
    // escribir en la carpeta de otro.
    const extension = archivo.name.split('.').pop()?.toLowerCase() ?? 'jpg'
    const ruta = `${idUsuario}/perfil-${Date.now()}.${extension}`

    const { error: errorSubida } = await supabase.storage
      .from('avatars')
      .upload(ruta, archivo, { upsert: true, contentType: archivo.type })

    if (errorSubida) {
      setSubiendo(false)
      return setError('No se pudo subir la foto. Probá de nuevo.')
    }

    const { error: errorPerfil } = await supabase
      .from('profiles')
      .update({ avatar_path: ruta })
      .eq('id', idUsuario)

    if (errorPerfil) {
      setSubiendo(false)
      return setError('La foto subió pero no se pudo guardar en tu perfil.')
    }

    const { data } = await supabase.storage.from('avatars').createSignedUrl(ruta, 3600)
    setVista(data?.signedUrl ?? null)
    setSubiendo(false)
    router.refresh()
  }

  return (
    <div className="flex items-center gap-5">
      <Avatar nombre={nombre} url={vista} tamaño={88} />
      <div className="space-y-2">
        <input
          ref={entrada}
          type="file"
          accept={TIPOS.join(',')}
          className="sr-only"
          onChange={(e) => {
            const archivo = e.target.files?.[0]
            if (archivo) void subir(archivo)
          }}
        />
        <Boton
          type="button"
          variante="secundario"
          disabled={subiendo}
          onClick={() => entrada.current?.click()}
        >
          {subiendo ? 'Subiendo…' : vista ? 'Cambiar foto' : 'Subir foto'}
        </Boton>
        <p className="text-xs text-mute">JPG, PNG o WEBP. Hasta 5 MB.</p>
        {error ? (
          <p role="alert" className="text-sm text-rose">
            {error}
          </p>
        ) : null}
      </div>
    </div>
  )
}
