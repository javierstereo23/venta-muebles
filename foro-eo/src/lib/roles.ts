import type { RolForo } from './tipos-db'

export const ETIQUETA_ROL: Record<RolForo, string> = {
  moderator: 'Moderador',
  moderator_elect: 'Moderador electo',
  moderator_outgoing: 'Moderador saliente',
  member: 'Miembro',
}

/** Edita la agenda, corre el cronometro, abre y cierra votaciones. */
export const esModerador = (rol: RolForo): boolean => rol === 'moderator'

/** Administra el Parking Lot y ordena los Deep Dives del año. */
export const puedeCurar = (rol: RolForo): boolean =>
  rol === 'moderator' || rol === 'moderator_elect'
