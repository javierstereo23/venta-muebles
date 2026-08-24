/** Contraste WCAG 2.1 entre dos colores hex. Sirve para probar la paleta. */

function aLineal(canal: number): number {
  const s = canal / 255
  return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4
}

export function luminancia(hex: string): number {
  const limpio = hex.replace('#', '')
  const r = Number.parseInt(limpio.slice(0, 2), 16)
  const g = Number.parseInt(limpio.slice(2, 4), 16)
  const b = Number.parseInt(limpio.slice(4, 6), 16)
  return 0.2126 * aLineal(r) + 0.7152 * aLineal(g) + 0.0722 * aLineal(b)
}

export function contraste(unColor: string, otroColor: string): number {
  const a = luminancia(unColor)
  const b = luminancia(otroColor)
  const claro = Math.max(a, b)
  const oscuro = Math.min(a, b)
  return (claro + 0.05) / (oscuro + 0.05)
}
