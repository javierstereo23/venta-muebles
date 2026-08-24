-- =============================================================================
-- 0004 · Reuniones, agenda por bloques y cronometro.
-- El cronometro vive en el servidor: si la tablet se recarga o se apaga la
-- pantalla, el tiempo transcurrido no se pierde y todos ven lo mismo.
-- =============================================================================

create table public.meetings (
  id           uuid primary key default gen_random_uuid(),
  forum_id     uuid not null references public.forums(id) on delete cascade,
  title        text,
  scheduled_at timestamptz not null,
  location     text,
  status       public.meeting_status not null default 'draft',
  opened_at    timestamptz,
  closed_at    timestamptz,
  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index on public.meetings (forum_id, scheduled_at desc);

create table public.agenda_blocks (
  id                    uuid primary key default gen_random_uuid(),
  meeting_id            uuid not null references public.meetings(id) on delete cascade,
  position              int  not null,
  title                 text not null,
  description           text,
  kind                  public.agenda_block_kind not null,
  duration_minutes      int  not null check (duration_minutes > 0 and duration_minutes <= 480),
  -- null => la hora se calcula encadenando duraciones desde meetings.scheduled_at.
  planned_start_at      timestamptz,
  timer_status          public.timer_state not null default 'idle',
  timer_started_at      timestamptz,
  timer_elapsed_seconds int not null default 0 check (timer_elapsed_seconds >= 0),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint agenda_blocks_position_uq unique (meeting_id, position) deferrable initially deferred
);
create index on public.agenda_blocks (meeting_id, position);

comment on column public.agenda_blocks.timer_elapsed_seconds is
  'Segundos acumulados de tramos ya cerrados. Transcurrido real = este valor + '
  '(now() - timer_started_at) si el estado es running. Puede superar la duracion '
  'planificada: el excedente es justamente la señal que interesa mostrar.';

create trigger touch_meetings      before update on public.meetings      for each row execute function app.touch_updated_at();
create trigger touch_agenda_blocks before update on public.agenda_blocks for each row execute function app.touch_updated_at();

-- -----------------------------------------------------------------------------
-- Plantilla base EO (4 h). Configurable: el moderador la edita antes de correrla.
-- Nota: 15 + 45 + 60 + 45 + 45 + 15 + dos breaks de 10 = 245' (4 h 05).
-- El bloque de 90' de la metodologia se guarda partido en EQ (45') e IQ (45')
-- para no mezclar Deep Dive impromptu con temas IQ en un mismo bloque.
-- -----------------------------------------------------------------------------

create or replace function public.apply_agenda_template(p_meeting uuid)
returns setof public.agenda_blocks
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_forum uuid;
begin
  select forum_id into v_forum from public.meetings where id = p_meeting;
  if v_forum is null then
    raise exception 'La reunion % no existe.', p_meeting using errcode = '22023';
  end if;
  if not app.is_moderator(v_forum) then
    raise exception 'Solo el moderador puede armar la agenda.' using errcode = '42501';
  end if;
  if exists (select 1 from public.agenda_blocks where meeting_id = p_meeting) then
    raise exception 'La reunion ya tiene agenda cargada.' using errcode = '23505';
  end if;

  return query
  insert into public.agenda_blocks (meeting_id, position, title, description, kind, duration_minutes)
  values
    (p_meeting, 1, 'Rituales de apertura',        'Cornerstones, icebreaker y check-in.',                  'ritual', 15),
    (p_meeting, 2, '5% Reflections + Parking Lot','Cada uno comparte su 5%. Silencio o resonancia, nunca respuesta al presentador.', 'eq', 45),
    (p_meeting, 3, 'Break',                        null,                                                    'break',  10),
    (p_meeting, 4, 'Deep Dive planificado',        'Tema Q2 agendado. Experiencia propia, sin consejos.',   'eq',     60),
    (p_meeting, 5, 'Break',                        null,                                                    'break',  10),
    (p_meeting, 6, 'Deep Dive impromptu',          'Tema EQ que surge en la sala.',                          'eq',     45),
    (p_meeting, 7, 'Temas IQ / brainstorm',        'Que y como: recursos, expertos, accountability.',        'iq',     45),
    (p_meeting, 8, 'Rituales de cierre',           'Triangulo de valor, puntaje y cierre.',                  'ritual', 15)
  returning *;
end;
$$;

-- -----------------------------------------------------------------------------
-- Cronometro (RPCs: la hora la pone el servidor, no la tablet).
-- -----------------------------------------------------------------------------

create or replace function app.assert_can_run_timer(p_block uuid)
returns void language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_forum uuid;
begin
  select m.forum_id into v_forum
  from public.agenda_blocks b join public.meetings m on m.id = b.meeting_id
  where b.id = p_block;
  if v_forum is null then
    raise exception 'El bloque % no existe.', p_block using errcode = '22023';
  end if;
  if not app.is_moderator(v_forum) then
    raise exception 'Solo el moderador corre el cronometro.' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.timer_start(p_block uuid)
returns public.agenda_blocks
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_row public.agenda_blocks;
begin
  perform app.assert_can_run_timer(p_block);
  update public.agenda_blocks
     set timer_status = 'running', timer_started_at = clock_timestamp()
   where id = p_block and timer_status <> 'running'
  returning * into v_row;
  if v_row.id is null then
    select * into v_row from public.agenda_blocks where id = p_block;  -- ya estaba corriendo
  end if;
  return v_row;
end;
$$;

create or replace function public.timer_pause(p_block uuid)
returns public.agenda_blocks
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_row public.agenda_blocks;
begin
  perform app.assert_can_run_timer(p_block);
  update public.agenda_blocks
     set timer_status = 'paused',
         timer_elapsed_seconds = timer_elapsed_seconds
           + case when timer_status = 'running'
                  then greatest(0, extract(epoch from (clock_timestamp() - timer_started_at))::int)
                  else 0 end,
         timer_started_at = null
   where id = p_block
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function public.timer_finish(p_block uuid)
returns public.agenda_blocks
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_row public.agenda_blocks;
begin
  perform app.assert_can_run_timer(p_block);
  update public.agenda_blocks
     set timer_status = 'done',
         timer_elapsed_seconds = timer_elapsed_seconds
           + case when timer_status = 'running'
                  then greatest(0, extract(epoch from (clock_timestamp() - timer_started_at))::int)
                  else 0 end,
         timer_started_at = null
   where id = p_block
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function public.timer_reset(p_block uuid)
returns public.agenda_blocks
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_row public.agenda_blocks;
begin
  perform app.assert_can_run_timer(p_block);
  update public.agenda_blocks
     set timer_status = 'idle', timer_started_at = null, timer_elapsed_seconds = 0
   where id = p_block
  returning * into v_row;
  return v_row;
end;
$$;

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------

alter table public.meetings      enable row level security;
alter table public.agenda_blocks enable row level security;

create policy meetings_select on public.meetings
  for select to authenticated using (app.is_forum_member(forum_id));
create policy meetings_write on public.meetings
  for all to authenticated using (app.is_moderator(forum_id)) with check (app.is_moderator(forum_id));

create policy agenda_select on public.agenda_blocks
  for select to authenticated
  using (exists (
    select 1 from public.meetings m
    where m.id = meeting_id and app.is_forum_member(m.forum_id)
  ));
create policy agenda_write on public.agenda_blocks
  for all to authenticated
  using (exists (
    select 1 from public.meetings m
    where m.id = meeting_id and app.is_moderator(m.forum_id)
  ))
  with check (exists (
    select 1 from public.meetings m
    where m.id = meeting_id and app.is_moderator(m.forum_id)
  ));
