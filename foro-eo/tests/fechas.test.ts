import { describe, expect, it } from 'vitest'
import { aInstante, aValorFecha, descomponerCuenta, diaYFecha, hora, rangoHorario } from '@/lib/fechas'

describe('fechas del foro', () => {
  it('arma el instante del próximo foro en hora de Buenos Aires', () => {
    const inicio = aInstante('2026-11-03', '16:00')
    expect(inicio).toBe('2026-11-03T16:00:00-03:00')
    expect(new Date(inicio).toISOString()).toBe('2026-11-03T19:00:00.000Z')
  })

  it('muestra la hora de Buenos Aires aunque el dispositivo esté en otra zona', () => {
    const inicio = '2026-11-03T19:00:00.000Z'
    expect(hora(inicio)).toBe('16:00')
    expect(diaYFecha(inicio)).toContain('3 de noviembre')
    expect(diaYFecha(inicio)).toContain('martes')
    expect(aValorFecha(inicio)).toBe('2026-11-03')
  })

  it('arma el rango horario del foro', () => {
    expect(rangoHorario('2026-11-03T19:00:00.000Z', '2026-11-03T23:00:00.000Z')).toBe('16:00 a 20:00')
    expect(rangoHorario('2026-11-03T19:00:00.000Z', null)).toBe('16:00')
  })

  it('descompone la cuenta regresiva', () => {
    const faltan = 2 * 86400000 + 3 * 3600000 + 4 * 60000 + 5000
    expect(descomponerCuenta(faltan)).toEqual({
      dias: 2,
      horas: 3,
      minutos: 4,
      segundos: 5,
      pasada: false,
    })
  })

  it('avisa cuando la reunión ya pasó', () => {
    expect(descomponerCuenta(-60000).pasada).toBe(true)
    expect(descomponerCuenta(-60000).minutos).toBe(1)
    expect(descomponerCuenta(0).pasada).toBe(true)
  })
})
