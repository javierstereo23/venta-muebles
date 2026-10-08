import { CORNERSTONES } from '@/lib/cornerstones'

export function Cornerstones() {
  return (
    <section aria-labelledby="cornerstones">
      <h2 id="cornerstones" className="font-display text-2xl">
        Los cuatro cornerstones
      </h2>
      <p className="mt-2 max-w-2xl text-sm text-mute">
        Vienen de la metodología y se reafirman al abrir cada reunión. No se editan.
      </p>
      <ul className="mt-6 grid gap-4 sm:grid-cols-2">
        {CORNERSTONES.map((piedra) => (
          <li key={piedra.titulo} className="rounded-xl2 border border-line bg-deep p-5">
            <h3 className="font-display text-lg text-bone">{piedra.titulo}</h3>
            <p className="mt-2 text-sm leading-relaxed text-mute">{piedra.texto}</p>
          </li>
        ))}
      </ul>
    </section>
  )
}
