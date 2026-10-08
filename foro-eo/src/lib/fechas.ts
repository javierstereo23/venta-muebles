/** Fechas y horas del foro, siempre en la zona de Buenos Aires. */

export const ZONA = 'America/Argentina/Buenos_Aires'

// Argentina no usa horario de verano desde 2009, así que el desfase es fijo.
// Si algún día vuelve, esto es lo único que hay que tocar: lo que se guarda en
// la base es un instante absoluto, no una hora de pared.
export const DESFASE = '-03:00'

/** '2026-11-03' + '16:00' → instante absoluto en ISO. */
export function aInstante(fecha: string, hora: string): string {
  return `${fecha}T${hora.length === 5 ? `${hora}:00` : hora}${DESFASE}`
}

export interface Cuenta {
  dias: number
  horas: number
  minutos: number
  segundos: number
  pasada: boolean
}

export function descomponerCuenta(milisegundos: number): Cuenta {
  const pasada = milisegundos <= 0
  const total = Math.floor(Math.abs(milisegundos) / 1000)
  return {
    dias: Math.floor(total / 86400),
    horas: Math.floor((total % 86400) / 3600),
    minutos: Math.floor((total % 3600) / 60),
    segundos: total % 60,
    pasada,
  }
}

const DIA_Y_FECHA = new Intl.DateTimeFormat('es-AR', {
  timeZone: ZONA,
  weekday: 'long',
  day: 'numeric',
  month: 'long',
})

const SOLO_HORA = new Intl.DateTimeFormat('es-AR', {
  timeZone: ZONA,
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
})

/** 'martes 3 de noviembre' */
export function diaYFecha(iso: string): string {
  return DIA_Y_FECHA.format(new Date(iso))
}

/** '16:00' */
export function hora(iso: string): string {
  return SOLO_HORA.format(new Date(iso))
}

/** '16:00 a 20:00', o solo '16:00' si no hay hora de fin. */
export function rangoHorario(inicio: string, fin: string | null): string {
  return fin ? `${hora(inicio)} a ${hora(fin)}` : hora(inicio)
}

/** Para el value de un <input type="date"> leyendo la hora de Buenos Aires. */
export function aValorFecha(iso: string): string {
  const partes = new Intl.DateTimeFormat('en-CA', {
    timeZone: ZONA,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(iso))
  return partes
}
