import { expect, test } from '@playwright/test'

// Sin sesion no se ve nada: ni el inicio, ni los miembros, ni el perfil.
const PRIVADAS = ['/', '/miembros', '/perfil']

test.describe('acceso', () => {
  for (const ruta of PRIVADAS) {
    test(`sin sesión, ${ruta} manda a entrar`, async ({ page }) => {
      await page.goto(ruta)
      await expect(page).toHaveURL(/\/entrar$/)
    })
  }

  test('la pantalla de ingreso pide el email y no ofrece contraseña', async ({ page }) => {
    await page.goto('/entrar')
    await expect(page.getByLabel('Tu email')).toBeVisible()
    await expect(page.getByRole('button', { name: 'Mandame el link' })).toBeVisible()
    await expect(page.locator('input[type="password"]')).toHaveCount(0)
  })

  test('el foco de teclado se ve en los controles', async ({ page }) => {
    await page.goto('/entrar')
    await page.getByLabel('Tu email').focus()
    const outline = await page
      .getByLabel('Tu email')
      .evaluate((el) => getComputedStyle(el).outlineWidth)
    expect(outline).not.toBe('0px')
  })
})
