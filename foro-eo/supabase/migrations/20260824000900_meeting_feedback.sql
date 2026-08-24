-- =============================================================================
-- 0009 · Cierre de reunion: triangulo de valor + puntaje.
--
-- ANONIMATO: cada uno lee unicamente su propia fila. El foro ve promedios,
-- cantidad de respuestas y tendencia; nunca quien puso que. Los comentarios
-- ("que la habria hecho un punto mejor") se devuelven sin autor y recien a
-- partir de 3 respuestas, para que con pocas respuestas no sea deducible.
-- =============================================================================

create table public.meeting_feedback (
  id                   uuid primary key default gen_random_uuid(),
  meeting_id           uuid not null references public.meetings(id) on delete cascade,
  member_id            uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  overall_score        int  check (overall_score between 1 and 10),
  one_point_better     text,
  connection           int  check (connection between 1 and 10),
  personal_growth      int  check (personal_growth between 1 and 10),
  business_takeaways   int  check (business_takeaways between 1 and 10),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint meeting_feedback_one_per_member unique (meeting_id, member_id)
);

create trigger touch_meeting_feedback before update on public.meeting_feedback
  for each row execute function app.touch_updated_at();

alter table public.meeting_feedback enable row level security;

create policy meeting_feedback_own on public.meeting_feedback
  for all to authenticated
  using (member_id = auth.uid())
  with check (
    member_id = auth.uid()
    and exists (select 1 from public.meetings m
                where m.id = meeting_id and app.is_forum_member(m.forum_id))
  );

-- Vista agregada. security_invoker = false a proposito: corre con los permisos
-- del dueño (saltea la RLS de meeting_feedback) y por eso NO expone member_id.
-- El filtro por membresia hace de barrera entre foros.
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

create or replace function public.meeting_feedback_notes(p_meeting uuid)
returns table (note text)
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_forum uuid;
  v_count int;
begin
  select forum_id into v_forum from public.meetings where id = p_meeting;
  if v_forum is null or not app.is_forum_member(v_forum) then
    raise exception 'No existe esa reunion o no es de tu foro.' using errcode = '42501';
  end if;

  select count(*) into v_count
  from public.meeting_feedback f
  where f.meeting_id = p_meeting and coalesce(btrim(f.one_point_better), '') <> '';

  if v_count < 3 then
    return;  -- con menos de 3 comentarios se podria inferir quien escribio que
  end if;

  return query
  select f.one_point_better
  from public.meeting_feedback f
  where f.meeting_id = p_meeting and coalesce(btrim(f.one_point_better), '') <> ''
  order by random();
end;
$$;
