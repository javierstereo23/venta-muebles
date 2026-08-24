import { defineConfig, devices } from '@playwright/test'

// CHROMIUM_PATH permite apuntar a un Chromium ya instalado en la maquina en vez
// de bajar uno nuevo. Sin esa variable, Playwright usa el suyo.
const executablePath = process.env.CHROMIUM_PATH

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  reporter: 'list',
  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:3111',
    ...(executablePath ? { launchOptions: { executablePath } } : {}),
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: process.env.BASE_URL
    ? undefined
    : {
        command: 'npx next start -p 3111',
        port: 3111,
        reuseExistingServer: true,
        env: {
          NEXT_PUBLIC_SUPABASE_URL:
            process.env.NEXT_PUBLIC_SUPABASE_URL ?? 'https://ejemplo.supabase.co',
          NEXT_PUBLIC_SUPABASE_ANON_KEY:
            process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? 'clave-de-prueba',
        },
      },
})
