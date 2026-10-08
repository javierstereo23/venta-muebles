/**
 * El único lugar donde el iceberg aparece literal: la línea de flotación que
 * separa lo que se ve de lo que lo sostiene. No se repite en otras pantallas.
 */
export function LineaDeFlotacion({ texto }: { texto: string }) {
  return (
    <div className="relative my-16 flex items-center gap-4" role="separator" aria-label={texto}>
      <span className="h-px flex-1 bg-gradient-to-r from-transparent via-line to-line" />
      <span className="font-mono text-[0.65rem] uppercase tracking-[0.25em] text-mute">{texto}</span>
      <span className="h-px flex-1 bg-gradient-to-l from-transparent via-line to-line" />
    </div>
  )
}
