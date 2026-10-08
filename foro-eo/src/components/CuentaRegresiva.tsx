'use client'

import { useEffect, useState } from 'react'
import { descomponerCuenta } from '@/lib/fechas'

const UNIDADES = [
  ['dias', 'días'],
  ['horas', 'horas'],
  ['minutos', 'min'],
] as const

export function CuentaRegresiva({ hasta }: { hasta: string }) {
  // Arranca en null para que el primer render del servidor y el del navegador
  // digan lo mismo: si no, la hidratación se queja.
  const [restante, setRestante] = useState<number | null>(null)

  useEffect(() => {
    const destino = new Date(hasta).getTime()
    const latir = () => setRestante(destino - Date.now())
    latir()
    const id = setInterval(latir, 1000)
    return () => clearInterval(id)
  }, [hasta])

  if (restante === null) {
    return <p className="font-mono text-sm text-mute">Calculando…</p>
  }

  const cuenta = descomponerCuenta(restante)

  if (cuenta.pasada) {
    return (
      <p className="font-mono text-sm uppercase tracking-widest text-amber">
        {cuenta.dias > 0 ? `Pasó hace ${cuenta.dias} ${cuenta.dias === 1 ? 'día' : 'días'}` : 'Es hoy'}
      </p>
    )
  }

  return (
    <dl className="flex items-end gap-5" aria-label="Cuenta regresiva">
      {UNIDADES.map(([clave, etiqueta]) => (
        <div key={clave}>
          <dd className="font-mono text-3xl tabular-nums leading-none text-bone sm:text-4xl">
            {String(cuenta[clave]).padStart(2, '0')}
          </dd>
          <dt className="mt-1.5 font-mono text-[0.65rem] uppercase tracking-[0.2em] text-mute">
            {etiqueta}
          </dt>
        </div>
      ))}
    </dl>
  )
}
