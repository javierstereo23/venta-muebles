import { forwardRef } from 'react'

type Variante = 'primario' | 'secundario' | 'fantasma'

// Sobre azul va texto blanco; sobre los calidos, texto oscuro. Es la unica
// combinacion que cumple 4.5:1 en cada caso.
const ESTILOS: Record<Variante, string> = {
  primario: 'bg-blue text-white hover:brightness-110',
  secundario: 'bg-shelf text-bone border border-edge hover:bg-line',
  fantasma: 'text-mute hover:text-bone',
}

export interface PropsBoton extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variante?: Variante
}

export const Boton = forwardRef<HTMLButtonElement, PropsBoton>(function Boton(
  { variante = 'primario', className = '', ...props },
  ref,
) {
  return (
    <button
      ref={ref}
      className={`inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-medium transition-[filter,background-color] disabled:cursor-not-allowed disabled:opacity-60 ${ESTILOS[variante]} ${className}`}
      {...props}
    />
  )
})
