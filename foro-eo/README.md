# Foro EO — plataforma

Aplicación del Foro EO Buenos Aires.

| Módulo | Estado |
|---|---|
| Esquema de base + RLS | ✅ implementado y probado contra un Postgres real |
| 5.1 Autenticación y miembros | ✅ implementado — falta probarlo contra un proyecto Supabase real |
| 5.2 Inicio | pendiente |
| 5.3 Agenda y cronómetro | base de datos lista, UI pendiente |
| 5.4 5% Reflections + one-pager | base de datos lista, UI pendiente |
| 5.5 Parking Lot | base de datos lista, UI pendiente |
| 5.6 Icebreaker | base de datos lista, UI pendiente |
| 5.7 Votos y salud del foro | base de datos lista, UI pendiente |

## Estructura

```
foro-eo/
├── src/
│   ├── app/            rutas (App Router)
│   ├── components/     primitivas de UI
│   ├── lib/            clientes de Supabase, sesión, roles, contraste
│   └── middleware.ts   sin sesión no se ve ninguna ruta
├── supabase/
│   ├── migrations/     10 migraciones
│   ├── seed.sql        el foro, los ocho de la lista blanca, los icebreakers
│   └── tests/          shim local de Supabase + 15 chequeos de RLS
├── e2e/                Playwright
├── tests/              Vitest
└── docs/esquema.md     el modelo de datos, explicado
```

## Correr

```bash
npm install
cp .env.example .env.local     # completar con los datos del proyecto Supabase
npm run dev
```

## Probar

```bash
npm run test:db      # 15 chequeos de RLS contra un Postgres 16 efímero
npm run test         # Vitest: permisos por rol y contraste WCAG de la paleta
npm run typecheck    # TypeScript en modo estricto
npm run build
CHROMIUM_PATH=/ruta/al/chromium npm run test:e2e   # sin la variable usa el Chromium de Playwright
```

`test:db` levanta un Postgres descartable, aplica las migraciones y el seed, y
verifica las políticas. No toca ninguna base real.

## Aplicar en Supabase

```bash
supabase link --project-ref <ref>
supabase db push
psql "$DATABASE_URL" -f supabase/seed.sql
```

Antes de invitar a nadie hay que reemplazar en `seed.sql` los emails
`@example.invalid` por los reales. Ese dominio no puede recibir correo, así que
mientras tanto no habilitan a nadie.

En el panel de Supabase: **Auth → URL Configuration** tiene que incluir
`<sitio>/auth/callback` como redirect permitido, y conviene apagar el registro
por contraseña. El shim de `supabase/tests/00_local_shim.sql` **no se aplica
nunca** a Supabase.

## Reglas del producto que el código hace cumplir

- El 5% de cada uno es privado. No hay policy que le dé acceso al moderador.
- Lo único que sale del 5% al grupo es el titular que su autor decide publicar.
- El rol `anon` no tiene un solo permiso: no hay pantallas públicas ni links para compartir.
- Sin exportación masiva, sin analytics de terceros, sin logs con contenido del 5%.
- El asistente corre siempre del lado del servidor y nunca recibe el 5% de otra persona.
- Las fotos viven en un bucket privado y se sirven con URLs firmadas de una hora.
