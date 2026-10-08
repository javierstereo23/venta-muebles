/**
 * Sedes con formulario propio.
 *
 * Esta es la ÚNICA puerta por la que sale algo del sistema, y sale a propósito:
 * una reserva de sala necesita fecha, horario y cuánta gente va. Lo que se
 * manda está acotado al tipo `DatosReserva` de abajo: nunca contenido del 5%,
 * nunca la lista de miembros, nunca nada del Parking Lot.
 *
 * El mapeo de campos (`entry.<id>`) sale de abrir el formulario y mirar el
 * HTML: cada pregunta tiene su propio id. Está acá y no en la base porque es
 * configuración pública y de una sola sede; si mañana hay varias, se mueve.
 */

export interface DatosReserva {
  fecha: string // 2026-11-03
  desde: string // 16:00
  hasta: string // 20:00
  personas: number
  responsable: string
  email: string
}

export interface FormularioSede {
  /** Cómo aparece escrito el lugar en la reunión, sin distinguir mayúsculas. */
  lugar: string
  /** El id largo del formulario, el que va entre /e/ y /viewform. */
  formId: string
  /** Qué dato va en cada pregunta. Las que no apliquen, se dejan afuera. */
  campos: Partial<Record<keyof DatosReserva, string>>
  /** Valores fijos que el formulario pide y no salen de la reunión. */
  constantes?: Record<string, string>
}

export const FORMULARIOS_DE_SEDE: FormularioSede[] = [
  {
    lugar: 'Hit Polo',
    formId: '1FAIpQLSehbP5az6gAoDUirOa8pY2O1_S5UjxK-DKNJMa3J5nKAtXauw',
    // TODO: completar con los entry.<id> reales de cada pregunta del
    // formulario. Hasta que estén, la integración queda apagada: sin campos no
    // se arma ninguna URL.
    campos: {},
  },
]

/** La sede, haya o no quedado configurado su formulario. */
export function sedeDeclarada(lugar: string | null): FormularioSede | null {
  if (!lugar) return null
  const normalizado = lugar.trim().toLowerCase()
  return FORMULARIOS_DE_SEDE.find((f) => f.lugar.toLowerCase() === normalizado) ?? null
}

export function estaConfigurada(sede: FormularioSede): boolean {
  return Object.keys(sede.campos).length > 0 || Object.keys(sede.constantes ?? {}).length > 0
}

/** La sede solo si ya se puede armar el formulario. Si falta el mapeo, null. */
export function formularioDeSede(lugar: string | null): FormularioSede | null {
  const sede = sedeDeclarada(lugar)
  return sede && estaConfigurada(sede) ? sede : null
}

/** Los pares entry.<id>=valor que entiende el formulario. */
export function paresDelFormulario(sede: FormularioSede, datos: DatosReserva): [string, string][] {
  const pares: [string, string][] = []

  for (const [dato, entry] of Object.entries(sede.campos)) {
    const valor = datos[dato as keyof DatosReserva]
    if (entry && valor !== undefined && valor !== null && String(valor) !== '') {
      pares.push([entry, String(valor)])
    }
  }
  for (const [entry, valor] of Object.entries(sede.constantes ?? {})) {
    pares.push([entry, valor])
  }

  return pares
}

/** Link con todo cargado: se abre, se revisa y se manda. */
export function urlPrecargada(sede: FormularioSede, datos: DatosReserva): string {
  const parametros = new URLSearchParams({ usp: 'pp_url' })
  for (const [entry, valor] of paresDelFormulario(sede, datos)) {
    parametros.append(entry, valor)
  }
  return `https://docs.google.com/forms/d/e/${sede.formId}/viewform?${parametros.toString()}`
}

/** A dónde y con qué cuerpo se envía, si se decide mandarlo solo. */
export function envioDirecto(
  sede: FormularioSede,
  datos: DatosReserva,
): { url: string; cuerpo: URLSearchParams } {
  const cuerpo = new URLSearchParams()
  for (const [entry, valor] of paresDelFormulario(sede, datos)) {
    cuerpo.append(entry, valor)
  }
  return {
    url: `https://docs.google.com/forms/d/e/${sede.formId}/formResponse`,
    cuerpo,
  }
}
