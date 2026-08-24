interface PropsAvatar {
  nombre: string
  url: string | null
  tamaño?: number
}

function iniciales(nombre: string): string {
  return nombre
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((parte) => parte[0]?.toUpperCase() ?? '')
    .join('')
}

export function Avatar({ nombre, url, tamaño = 56 }: PropsAvatar) {
  const estilo = { width: tamaño, height: tamaño }

  if (!url) {
    return (
      <div
        style={estilo}
        aria-hidden
        className="flex shrink-0 items-center justify-center rounded-full border border-edge bg-shelf font-display text-lg text-mute"
      >
        {iniciales(nombre)}
      </div>
    )
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={url}
      alt={`Foto de ${nombre}`}
      style={estilo}
      className="shrink-0 rounded-full border border-line object-cover"
    />
  )
}
