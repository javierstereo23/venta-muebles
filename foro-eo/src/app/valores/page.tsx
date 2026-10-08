import type { Metadata } from 'next'
import Link from 'next/link'
import { exigirPerfil } from '@/lib/sesion'
import { crearClienteServidor } from '@/lib/supabase/server'
import { Navegacion } from '@/components/Navegacion'
import { Boton } from '@/components/Boton'
import { Campo } from '@/components/Campo'
import { agregarValor, actualizarValor, borrarValor } from './acciones'
import type { ValorForo } from '@/lib/tipos-db'

export const metadata: Metadata = { title: 'Valores · Foro EO' }

export default async function PaginaValores() {
  const perfil = await exigirPerfil()
  const supabase = await crearClienteServidor()
  const { data } = await supabase.from('forum_values').select('*').order('position')
  const valores: ValorForo[] = data ?? []

  return (
    <>
      <Navegacion perfil={perfil} />
      <main className="mx-auto max-w-3xl px-6 py-12">
        <h1 className="font-display text-3xl">Valores del foro</h1>
        <p className="mt-2 max-w-xl text-sm leading-relaxed text-mute">
          Son del grupo: cualquiera de los ocho puede escribirlos, corregirlos o sacarlos. Los
          cornerstones, en cambio, vienen de la metodología y no se tocan.
        </p>

        <ul className="mt-10 space-y-4">
          {valores.map((valor) => (
            <li key={valor.id} className="rounded-xl2 border border-line bg-deep p-5">
              <form action={actualizarValor} className="flex flex-col gap-4">
                <input type="hidden" name="id" value={valor.id} />
                <Campo etiqueta="Valor" name="label" defaultValue={valor.label} required />
                <div className="flex flex-col gap-1.5">
                  <label htmlFor={`body-${valor.id}`} className="text-sm font-medium text-bone">
                    Qué significa para el foro
                  </label>
                  <textarea
                    id={`body-${valor.id}`}
                    name="body"
                    rows={2}
                    defaultValue={valor.body ?? ''}
                    className="rounded-lg border border-edge bg-shelf px-3 py-2.5 text-bone placeholder:text-mute"
                  />
                </div>
                <div className="flex items-center gap-3">
                  <Boton type="submit" variante="secundario">
                    Guardar
                  </Boton>
                  <Boton type="submit" variante="fantasma" formNoValidate formAction={borrarValor}>
                    Sacar
                  </Boton>
                </div>
              </form>
            </li>
          ))}
          {valores.length === 0 ? (
            <li className="rounded-xl2 border border-dashed border-line p-6 text-sm text-mute">
              Todavía no escribieron los valores del foro. Es una buena primera conversación.
            </li>
          ) : null}
        </ul>

        <form action={agregarValor} className="mt-10 flex flex-col gap-4 border-t border-line pt-10">
          <h2 className="font-display text-xl">Agregar un valor</h2>
          <Campo etiqueta="Valor" name="label" required placeholder="Presencia" />
          <div className="flex flex-col gap-1.5">
            <label htmlFor="body-nuevo" className="text-sm font-medium text-bone">
              Qué significa para el foro
            </label>
            <textarea
              id="body-nuevo"
              name="body"
              rows={2}
              placeholder="Llegamos a horario y nos quedamos las cuatro horas."
              className="rounded-lg border border-edge bg-shelf px-3 py-2.5 text-bone placeholder:text-mute"
            />
          </div>
          <div>
            <Boton type="submit">Agregar</Boton>
          </div>
        </form>

        <p className="mt-10 text-sm">
          <Link href="/" className="text-mute hover:text-bone">
            ← Volver al inicio
          </Link>
        </p>
      </main>
    </>
  )
}
