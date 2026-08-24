# Foro EO — plataforma

Aplicación del Foro EO Buenos Aires. Estado: **esquema de base y RLS, para revisar.**
Todavía no hay UI: el acuerdo es revisar el modelo antes de escribir la primera pantalla.

## Qué hay hoy

```
foro-eo/
├── supabase/
│   ├── migrations/     10 migraciones: tipos, foro, perfiles, storage, agenda,
│   │                   5%, parking lot, icebreaker, votaciones, feedback, permisos
│   ├── seed.sql        el foro, los ocho de la lista blanca, el catálogo inicial
│   └── tests/          shim local de Supabase + 15 chequeos de RLS
├── scripts/db-test.sh  levanta un Postgres efímero y corre todo
└── docs/esquema.md     el documento a revisar
```

## Correr la verificación

```bash
./scripts/db-test.sh
```

Levanta un Postgres 16 descartable, aplica las migraciones y el seed, y corre los
15 chequeos de privacidad y permisos. No toca ninguna base real. Termina en
`TODOS LOS CHEQUEOS PASARON` o falla con el nombre del chequeo que se rompió.

## Aplicar en Supabase

```bash
supabase link --project-ref <ref>
supabase db push          # aplica supabase/migrations/
psql "$DATABASE_URL" -f supabase/seed.sql
```

El shim de `supabase/tests/00_local_shim.sql` **no se aplica nunca** a Supabase:
existe solo para poder correr las policies contra un Postgres pelado.

Antes de invitar a nadie hay que reemplazar en `seed.sql` los emails
`@example.invalid` por los reales. Ese dominio no puede recibir correo, así que
mientras tanto no habilitan a nadie.

## Reglas del producto que el código hace cumplir

- El 5% de cada uno es privado. No hay policy que le dé acceso al moderador.
- Lo único que sale del 5% al grupo es el titular que su autor decide publicar.
- El rol `anon` no tiene un solo permiso: no hay pantallas públicas ni links para compartir.
- Sin exportación masiva, sin analytics de terceros, sin logs con contenido del 5%.
- El asistente corre siempre del lado del servidor y nunca recibe el 5% de otra persona.
