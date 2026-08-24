import type { Metadata } from 'next'
import { exigirPerfil, urlFirmadaAvatar } from '@/lib/sesion'
import { Navegacion } from '@/components/Navegacion'
import { ETIQUETA_ROL } from '@/lib/roles'
import { FormularioPerfil } from './FormularioPerfil'
import { SubidaFoto } from './SubidaFoto'

export const metadata: Metadata = { title: 'Mi perfil · Foro EO' }

export default async function PaginaPerfil() {
  const perfil = await exigirPerfil()
  const foto = await urlFirmadaAvatar(perfil.avatar_path)

  return (
    <>
      <Navegacion perfil={perfil} />
      <main className="mx-auto max-w-5xl px-6 py-12">
        <h1 className="font-display text-3xl">Mi perfil</h1>
        <p className="mt-2 font-mono text-xs uppercase tracking-widest text-mute">
          {ETIQUETA_ROL[perfil.role]}
        </p>

        <div className="mt-8 space-y-10">
          <SubidaFoto nombre={perfil.full_name} urlActual={foto} idUsuario={perfil.id} />
          <FormularioPerfil perfil={perfil} />
        </div>
      </main>
    </>
  )
}
