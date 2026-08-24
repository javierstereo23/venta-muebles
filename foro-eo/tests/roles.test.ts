import { describe, expect, it } from 'vitest'
import { ETIQUETA_ROL, esModerador, puedeCurar } from '@/lib/roles'
import type { RolForo } from '@/lib/tipos-db'

const ROLES: RolForo[] = ['member', 'moderator', 'moderator_elect', 'moderator_outgoing']

describe('permisos por rol', () => {
  it('la agenda, el cronómetro y las votaciones son del moderador', () => {
    expect(ROLES.filter(esModerador)).toEqual(['moderator'])
  })

  it('el Parking Lot lo curan el moderador y el moderador electo', () => {
    expect(ROLES.filter(puedeCurar)).toEqual(['moderator', 'moderator_elect'])
  })

  it('el moderador saliente no arrastra permisos', () => {
    expect(esModerador('moderator_outgoing')).toBe(false)
    expect(puedeCurar('moderator_outgoing')).toBe(false)
  })

  it('todos los roles tienen etiqueta en pantalla', () => {
    ROLES.forEach((rol) => expect(ETIQUETA_ROL[rol]).toBeTruthy())
  })
})
