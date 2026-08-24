-- =============================================================================
-- 0005 · 5% Reflections + one-pager. El corazon del producto.
--
-- PRIVACIDAD: el 5% es privado por defecto y sin excepciones. No hay un solo
-- camino por el que otro miembro -moderador incluido- pueda leerlo. Lo unico
-- que se hace visible al grupo es el titular que el autor decide publicar al
-- Parking Lot (migracion 0006), y se publica copiando el texto, no vinculandolo.
-- =============================================================================

create table public.reflections (
  id              uuid primary key default gen_random_uuid(),
  forum_id        uuid not null references public.forums(id) on delete cascade,
  author_id       uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  -- Mes al que corresponde el 5%. Siempre el dia 1.
  period_month    date not null,
  meeting_id      uuid references public.meetings(id) on delete set null,
  status          public.reflection_status not null default 'draft',
  outlook_30_60   text,                       -- como se ven los proximos 30-60 dias
  deep_dive_topic text,                       -- tema Q2 para Deep Dive (EQ)
  deep_dive_why   text,
  iq_topic        text,                       -- tema Q1 para aprender o decidir mejor
  iq_why          text,
  finalized_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint reflections_period_is_month check (period_month = date_trunc('month', period_month)::date),
  constraint reflections_one_per_month unique (author_id, period_month)
);
create index on public.reflections (author_id, period_month desc);

create table public.reflection_pillars (
  id            uuid primary key default gen_random_uuid(),
  reflection_id uuid not null references public.reflections(id) on delete cascade,
  pillar        public.pillar not null,
  -- 3 a 5 emociones, palabras sueltas. El limite duro se valida al finalizar,
  -- para no pelear con el guardado automatico mientras se escribe.
  emotions      text[] not null default '{}',
  cause         text,        -- que causo estos sentimientos
  significance  text,        -- por que esto es significativo para MI (el 80% invisible)
  updated_at    timestamptz not null default now(),
  constraint reflection_pillars_unique unique (reflection_id, pillar),
  constraint reflection_pillars_max_emotions check (coalesce(array_length(emotions, 1), 0) <= 5)
);

create table public.one_pagers (
  id                 uuid primary key default gen_random_uuid(),
  reflection_id      uuid not null unique references public.reflections(id) on delete cascade,
  headline           text not null,               -- 8 a 12 palabras
  headline_words     int generated always as
                       (coalesce(array_length(regexp_split_to_array(btrim(headline), '\s+'), 1), 0)) stored,
  whats_at_stake     text,                        -- que se me juega
  essence_questions  text[] not null default '{}',-- 3 preguntas de esencia
  pillar_summaries   jsonb  not null default '{}'::jsonb,
  parking_lot_eq     text,
  parking_lot_iq     text,
  model              text,
  prompt_version     text,
  context_reflection_ids uuid[] not null default '{}',
  generated_at       timestamptz not null default now(),
  constraint one_pagers_three_questions check (coalesce(array_length(essence_questions, 1), 0) <= 3)
);
comment on table public.one_pagers is
  'Salida del asistente. No se guarda el prompt ni la respuesta cruda: nada de '
  'logs con contenido del 5%. context_reflection_ids solo deja constancia de que '
  '5% previos -siempre del mismo autor- se usaron como contexto.';

create trigger touch_reflections        before update on public.reflections        for each row execute function app.touch_updated_at();
create trigger touch_reflection_pillars before update on public.reflection_pillars for each row execute function app.touch_updated_at();

-- Los tres pilares se crean con la reflexion: el formulario siempre tiene sus filas.
create or replace function app.seed_reflection_pillars()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.reflection_pillars (reflection_id, pillar)
  values (new.id, 'work'), (new.id, 'family'), (new.id, 'personal')
  on conflict do nothing;
  return new;
end;
$$;

create trigger seed_reflection_pillars
  after insert on public.reflections
  for each row execute function app.seed_reflection_pillars();

create or replace function public.finalize_reflection(p_reflection uuid)
returns public.reflections
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_row public.reflections;
  v_bad text;
begin
  select * into v_row from public.reflections where id = p_reflection;
  if v_row.id is null or v_row.author_id <> auth.uid() then
    raise exception 'No existe ese 5%% o no es tuyo.' using errcode = '42501';
  end if;

  select string_agg(pillar::text, ', ') into v_bad
  from public.reflection_pillars
  where reflection_id = p_reflection
    and (coalesce(array_length(emotions, 1), 0) < 3
      or coalesce(btrim(cause), '') = ''
      or coalesce(btrim(significance), '') = '');
  if v_bad is not null then
    raise exception 'Faltan datos en: %. Cada pilar necesita 3 a 5 emociones, causa y significado.', v_bad
      using errcode = '23514';
  end if;

  update public.reflections
     set status = 'final', finalized_at = now()
   where id = p_reflection
  returning * into v_row;
  return v_row;
end;
$$;

-- -----------------------------------------------------------------------------
-- RLS: autor y nadie mas. Ni SELECT, ni UPDATE, ni DELETE para terceros.
-- -----------------------------------------------------------------------------

alter table public.reflections        enable row level security;
alter table public.reflection_pillars enable row level security;
alter table public.one_pagers         enable row level security;

create policy reflections_owner_all on public.reflections
  for all to authenticated
  using (author_id = auth.uid())
  with check (author_id = auth.uid() and app.is_forum_member(forum_id));

create policy reflection_pillars_owner_all on public.reflection_pillars
  for all to authenticated
  using (exists (
    select 1 from public.reflections r where r.id = reflection_id and r.author_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.reflections r where r.id = reflection_id and r.author_id = auth.uid()
  ));

create policy one_pagers_owner_all on public.one_pagers
  for all to authenticated
  using (exists (
    select 1 from public.reflections r where r.id = reflection_id and r.author_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.reflections r where r.id = reflection_id and r.author_id = auth.uid()
  ));
