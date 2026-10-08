import { describe, expect, it } from 'vitest'
import {
  envioDirecto,
  estaConfigurada,
  formularioDeSede,
  sedeDeclarada,
  paresDelFormulario,
  urlPrecargada,
  type DatosReserva,
  type FormularioSede,
} from '@/lib/sedes'

const SEDE: FormularioSede = {
  lugar: 'Hit Polo',
  formId: 'FORM_DE_PRUEBA',
  campos: { fecha: 'entry.111', desde: 'entry.222', hasta: 'entry.333', responsable: 'entry.444' },
  constantes: { 'entry.999': 'Foro EO' },
}

const DATOS: DatosReserva = {
  fecha: '2026-11-03',
  desde: '16:00',
  hasta: '20:00',
  personas: 8,
  responsable: 'Javier Badaracco',
  email: 'javier@dynamo.tech',
  participantes: 'Javier Badaracco\nAriel Arrieta',
  participantesEmails: 'javier@dynamo.tech, ariel@ejemplo.com',
}

describe('formulario de la sede', () => {
  it('manda solo los campos mapeados, nada más', () => {
    const pares = paresDelFormulario(SEDE, DATOS)
    expect(pares).toEqual([
      ['entry.111', '2026-11-03'],
      ['entry.222', '16:00'],
      ['entry.333', '20:00'],
      ['entry.444', 'Javier Badaracco'],
      ['entry.999', 'Foro EO'],
    ])
    // el email no está mapeado, así que no viaja
    expect(JSON.stringify(pares)).not.toContain('dynamo')
  })

  it('arma el link precargado', () => {
    const url = new URL(urlPrecargada(SEDE, DATOS))
    expect(url.pathname).toBe('/forms/d/e/FORM_DE_PRUEBA/viewform')
    expect(url.searchParams.get('usp')).toBe('pp_url')
    expect(url.searchParams.get('entry.111')).toBe('2026-11-03')
    expect(url.searchParams.get('entry.222')).toBe('16:00')
  })

  it('arma el envío directo contra formResponse', () => {
    const { url, cuerpo } = envioDirecto(SEDE, DATOS)
    expect(url).toContain('/formResponse')
    expect(cuerpo.get('entry.444')).toBe('Javier Badaracco')
  })

  it('reconoce la sede sin importar mayúsculas ni espacios', () => {
    expect(sedeDeclarada('  hit polo ')?.lugar).toBe('Hit Polo')
  })

  it('no hace nada en otra sede', () => {
    expect(sedeDeclarada('Casa de Ariel')).toBeNull()
    expect(sedeDeclarada(null)).toBeNull()
    expect(formularioDeSede('Casa de Ariel')).toBeNull()
  })

  it('queda apagada mientras no estén los entry.<id> reales', () => {
    // Hit Polo está declarada, pero sin el mapeo no se arma ninguna URL: así la
    // integración no manda un formulario vacío sin que nadie se entere.
    expect(sedeDeclarada('Hit Polo')).not.toBeNull()
    expect(estaConfigurada(sedeDeclarada('Hit Polo')!)).toBe(false)
    expect(formularioDeSede('Hit Polo')).toBeNull()
  })
})

describe('participantes', () => {
  const GENTE = [
    { full_name: 'Javier Badaracco', email: 'javier@dynamo.tech' },
    { full_name: 'Ariel Arrieta', email: 'ariel@ejemplo.com' },
  ]

  it('arma la lista de quienes van', async () => {
    const { datosDeReserva } = await import('@/lib/sedes')
    const datos = datosDeReserva(
      { fecha: '2026-11-03', desde: '16:00', hasta: '20:00' },
      GENTE[0]!,
      GENTE,
    )
    expect(datos.personas).toBe(2)
    expect(datos.participantes).toBe('Javier Badaracco\nAriel Arrieta')
    expect(datos.participantesEmails).toBe('javier@dynamo.tech, ariel@ejemplo.com')
  })

  it('los datos de los demás no viajan si el formulario no los pide', async () => {
    const { datosDeReserva, paresDelFormulario } = await import('@/lib/sedes')
    const datos = datosDeReserva(
      { fecha: '2026-11-03', desde: '16:00', hasta: '20:00' },
      GENTE[0]!,
      GENTE,
    )
    // SEDE no mapea participantes ni participantesEmails
    const enviado = JSON.stringify(paresDelFormulario(SEDE, datos))
    expect(enviado).not.toContain('Ariel')
    expect(enviado).not.toContain('@')
  })

  it('el resumen dice en castellano qué se va a mandar', async () => {
    const { datosDeReserva, resumenDeLoQueSeManda } = await import('@/lib/sedes')
    const datos = datosDeReserva(
      { fecha: '2026-11-03', desde: '16:00', hasta: '20:00' },
      GENTE[0]!,
      GENTE,
    )
    const resumen = resumenDeLoQueSeManda(SEDE, datos)
    expect(resumen).toContainEqual({ etiqueta: 'Fecha', valor: '2026-11-03' })
    expect(resumen).toContainEqual({ etiqueta: 'Responsable', valor: 'Javier Badaracco' })
  })
})
