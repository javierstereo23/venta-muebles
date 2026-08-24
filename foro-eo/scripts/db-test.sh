#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Levanta un Postgres 16 efimero, aplica shim + migraciones + seed y corre la
# verificacion de RLS. No toca ninguna base real.
#   ./scripts/db-test.sh
# -----------------------------------------------------------------------------
set -euo pipefail

PGBIN="${PGBIN:-/usr/lib/postgresql/16/bin}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-${TMPDIR:-/tmp}/foro-eo-pgtest}"
PGDATA="$WORK/data"
SOCK="$WORK/sock"
PGUSER_RUN="${PGUSER_RUN:-postgres}"

# Postgres no arranca como root: nos pasamos al usuario del sistema.
if [ "$(id -u)" = "0" ]; then
  mkdir -p "$WORK"
  chown -R "$PGUSER_RUN" "$WORK"
  exec su "$PGUSER_RUN" -s /bin/bash -c "PGBIN='$PGBIN' WORK='$WORK' '$ROOT/scripts/db-test.sh'"
fi

rm -rf "$PGDATA" "$SOCK"
mkdir -p "$PGDATA" "$SOCK"

"$PGBIN/initdb" -D "$PGDATA" -U postgres --auth=trust >/dev/null
"$PGBIN/pg_ctl" -D "$PGDATA" -l "$WORK/server.log" \
  -o "-k '$SOCK' -c listen_addresses='' -c timezone=UTC -c lc_messages=C" -w start >/dev/null

cleanup() { "$PGBIN/pg_ctl" -D "$PGDATA" -m immediate stop >/dev/null 2>&1 || true; }
trap cleanup EXIT

export PGHOST="$SOCK" PGUSER=postgres PGDATABASE=foro_eo
"$PGBIN/createdb" -h "$SOCK" -U postgres foro_eo

run() { "$PGBIN/psql" -v ON_ERROR_STOP=1 -q -X -f "$1"; }

run "$ROOT/supabase/tests/00_local_shim.sql"
for f in "$ROOT"/supabase/migrations/*.sql; do
  echo "  migracion $(basename "$f")"
  run "$f"
done
run "$ROOT/supabase/seed.sql"
run "$ROOT/supabase/tests/10_fixtures.sql"
"$PGBIN/psql" -v ON_ERROR_STOP=1 -q -X -f "$ROOT/supabase/tests/20_rls_spec.sql"
