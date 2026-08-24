import { describe, expect, it } from 'vitest'
import { contraste } from '@/lib/contraste'
import config from '../tailwind.config'

const c = config.theme?.extend?.colors as Record<string, string>

const TEXTO = 4.5 // texto normal
const GRANDE = 3 // texto grande y bordes de controles

describe('la paleta cumple WCAG AA', () => {
  const superficies = [
    ['ink', c.ink],
    ['deep', c.deep],
    ['shelf', c.shelf],
  ] as const

  it.each(superficies)('texto principal sobre %s', (_nombre, fondo) => {
    expect(contraste(c.bone!, fondo!)).toBeGreaterThanOrEqual(TEXTO)
  })

  it.each(superficies)('texto secundario sobre %s', (_nombre, fondo) => {
    expect(contraste(c.mute!, fondo!)).toBeGreaterThanOrEqual(TEXTO)
  })

  it.each(superficies)('borde de control sobre %s', (_nombre, fondo) => {
    expect(contraste(c.edge!, fondo!)).toBeGreaterThanOrEqual(GRANDE)
  })

  it('el foco de teclado se distingue del fondo', () => {
    expect(contraste(c.focus!, c.ink!)).toBeGreaterThanOrEqual(GRANDE)
  })

  it('sobre azul va texto blanco', () => {
    expect(contraste('#FFFFFF', c.blue!)).toBeGreaterThanOrEqual(TEXTO)
  })

  // Sobre los calidos el texto blanco no llega a 4.5:1; el oscuro si.
  it.each([
    ['rose', c.rose],
    ['coral', c.coral],
    ['amber', c.amber],
    ['teal', c.teal],
  ])('sobre %s va texto oscuro, no blanco', (_nombre, fondo) => {
    expect(contraste(c.ink!, fondo!)).toBeGreaterThanOrEqual(TEXTO)
    expect(contraste('#FFFFFF', fondo!)).toBeLessThan(TEXTO)
  })
})
