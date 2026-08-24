-- =============================================================================
-- 0009 · Cierre de reunion: triangulo de valor + puntaje.
--
-- Dos formas de cargarlo, porque el foro usa las dos:
--   · source = 'room'  cada uno vota en voz alta y quien toma nota lo escribe.
--     Ya se dijo delante de todos, asi que se guarda con nombre y lo lee el foro.
--   · source = 'self'  cada uno lo carga desde su celular. Ese puntaje es
--     anonimo: solo su autor ve su fila; el resto ve promedios y los
--     comentarios sin autor.
-- Una fila por persona por reunion: si alguien ya cargo el suyo desde el
-- celular, quien toma nota no puede pisarlo.
-- =============================================================================

create table public.meeting_feedback (
  id                   uuid primary key default gen_random_uuid(),
  meeting_id           uuid not null references public.meetings(id) on delete cascade,
  member_id            uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  source               public.feedback_source not null default 'self',
  recorded_by          uuid references public.profiles(id) on delete set null,
  overall_score        int  check (overall_score between 1 and 10),
  one_point_better     text,
  connection           int  check (connection between 1 and 10),
  personal_growth      int  check (personal_growth between 1 and 10),
  business_takeaways   int  check (business_takeaways between 1 and 10),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint meeting_feedback_one_per_member unique (meeting_id, member_id),
  constraint meeting_feedback_recorder check (
    (source = 'self' and recorded_by is null) or (source = 'room' and recorded_by is not null)
  )
);
create index on public.meeting_feedback (meeting_id, source);

create trigger touch_meeting_feedback before update on public.meeting_feedback
  for each row execute function app.touch_updated_at();

-- El origen no se cambia despues: convertir un 'self' en 'room' publicaria algo
-- que se cargo en privado.
create or replace function app.freeze_feedback_source()
returns trigger language plpgsql as $$
begin
  if new.source is distinct from old.source then
    raise exception 'No se puede cambiar como se capturo un puntaje ya cargado.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger freeze_feedback_source before update on public.meeting_feedback
  for each row execute function app.freeze_feedback_source();

alter table public.meeting_feedback enable row level security;

create policy meeting_feedback_select on public.meeting_feedback
  for select to authenticated
  using (
    member_id = auth.uid()
    or (source = 'room' and exists (
          select 1 from public.meetings m
          where m.id = meeting_id and app.is_forum_member(m.forum_id)))
  );

create policy meeting_feedback_self on public.meeting_feedback
  for all to authenticated
  using (member_id = auth.uid() and source = 'self')
  with check (
    member_id = auth.uid() and source = 'self'
    and exists (select 1 from public.meetings m
                where m.id = meeting_id and app.is_forum_member(m.forum_id))
  );

-- Quien modera es quien toma nota de la ronda en voz alta.
create policy meeting_feedback_room on public.meeting_feedback
  for all to authenticated
  using (
    source = 'room'
    and exists (select 1 from public.meetings m
                where m.id = meeting_id and app.is_moderator(m.forum_id))
  )
  with check (
    source = 'room' and recorded_by = auth.uid()
    and exists (select 1 from public.meetings m
                where m.id = meeting_id and app.is_moderator(m.forum_id))
    and exists (select 1 from public.profiles p join public.meetings m on m.id = meeting_id
                where p.id = member_id and p.forum_id = m.forum_id)
  );

-- Promedios y tendencia del anio. security_invoker = false a proposito: corre
-- con permisos del dueño, saltea la RLS de la tabla base y por eso NO expone
-- member_id. El filtro por membresia es la barrera entre foros.
create view public.meeting_feedback_summary
with (security_invoker = false) as
select
  m.id           as meeting_id,
  m.forum_id     as forum_id,
  m.scheduled_at as scheduled_at,
  count(f.id)::int                  as respondents,
  round(avg(f.overall_score),      2) as avg_overall,
  round(avg(f.connection),         2) as avg_connection,
  round(avg(f.personal_growth),    2) as avg_personal_growth,
  round(avg(f.business_takeaways), 2) as avg_business_takeaways
from public.meetings m
left join public.meeting_feedback f on f.meeting_id = m.id
where app.is_forum_member(m.forum_id)
group by m.id, m.forum_id, m.scheduled_at;

revoke all on public.meeting_feedback_summary from anon;
grant select on public.meeting_feedback_summary to authenticated;

-- Quien ya respondio (sin puntajes): lo necesita quien toma nota para saber a
-- quien le falta. Dice que respondio, nunca que puso.
create view public.meeting_feedback_responded
with (security_invoker = false) as
select f.meeting_id, f.member_id, f.source
from public.meeting_feedback f
join public.meetings m on m.id = f.meeting_id
where app.is_forum_member(m.forum_id);

revoke all on public.meeting_feedback_responded from anon;
grant select on public.meeting_feedback_responded to authenticated;

-- Todos los resultados en un solo lugar: lo dicho en la sala con nombre, lo
-- cargado desde el celular sin autor.
create or replace function public.meeting_feedback_notes(p_meeting uuid)
returns table (note text, author text, source public.feedback_source)
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_forum uuid;
begin
  select forum_id into v_forum from public.meetings where id = p_meeting;
  if v_forum is null or not app.is_forum_member(v_forum) then
    raise exception 'No existe esa reunion o no es de tu foro.' using errcode = '42501';
  end if;

  return query
  select f.one_point_better,
         case when f.source = 'room' then p.full_name else null end,
         f.source
  from public.meeting_feedback f
  left join public.profiles p on p.id = f.member_id
  where f.meeting_id = p_meeting
    and coalesce(btrim(f.one_point_better), '') <> ''
  order by f.source desc, random();
end;
$$;
