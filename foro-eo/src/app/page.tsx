import { exigirPerfil } from '@/lib/sesion'
import { Navegacion } from '@/components/Navegacion'

// El Inicio completo (proposito, cuenta regresiva, retreat, cornerstones) es el
// modulo 5.2. Por ahora esta pantalla solo confirma que entraste.
export default async function PaginaInicio() {
  const perfil = await exigirPerfil()

  return (
    <>
      <Navegacion perfil={perfil} />
      <main className="mx-auto max-w-5xl px-6 py-16">
        <p className="font-mono text-xs uppercase tracking-[0.2em] text-mute">Foro EO Buenos Aires</p>
        <h1 className="mt-4 max-w-2xl font-display text-4xl leading-tight">
          Hola, {perfil.full_name.split(' ')[0]}.
        </h1>
        <p className="mt-4 max-w-xl text-sm leading-relaxed text-mute">
          Estás dentro. El Inicio con el propósito, la cuenta regresiva a la próxima reunión y los
          cuatro cornerstones llega en el próximo módulo.
        </p>
      </main>
    </>
  )
}
