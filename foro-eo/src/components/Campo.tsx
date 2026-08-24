interface PropsCampo extends React.InputHTMLAttributes<HTMLInputElement> {
  etiqueta: string
  ayuda?: string
}

export function Campo({ etiqueta, ayuda, id, className = '', ...props }: PropsCampo) {
  const idCampo = id ?? props.name ?? etiqueta
  const idAyuda = ayuda ? `${idCampo}-ayuda` : undefined

  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={idCampo} className="text-sm font-medium text-bone">
        {etiqueta}
      </label>
      <input
        id={idCampo}
        aria-describedby={idAyuda}
        className={`rounded-lg border border-edge bg-shelf px-3 py-2.5 text-bone placeholder:text-mute ${className}`}
        {...props}
      />
      {ayuda ? (
        <p id={idAyuda} className="text-xs text-mute">
          {ayuda}
        </p>
      ) : null}
    </div>
  )
}
