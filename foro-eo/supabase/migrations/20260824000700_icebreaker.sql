-- =============================================================================
-- 0007 · Icebreaker: catalogo editable y ruleta sin repeticion.
-- =============================================================================

create table public.icebreaker_prompts (
  id         uuid primary key default gen_random_uuid(),
  forum_id   uuid not null references public.forums(id) on delete cascade,
  text       text not null check (btrim(text) <> ''),
  is_active  boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.icebreaker_prompts (forum_id) where is_active;

create table public.icebreaker_draws (
  id         uuid primary key default gen_random_uuid(),
  forum_id   uuid not null references public.forums(id) on delete cascade,
  meeting_id uuid references public.meetings(id) on delete set null,
  prompt_id  uuid not null references public.icebreaker_prompts(id) on delete cascade,
  cycle      int  not null,
  drawn_by   uuid references public.profiles(id) on delete set null,
  drawn_at   timestamptz not null default now(),
  -- No se repite un disparador hasta agotar la lista: dentro de una vuelta
  -- (cycle) cada prompt puede salir una sola vez.
  constraint icebreaker_no_repeat_in_cycle unique (forum_id, cycle, prompt_id)
);

create trigger touch_icebreaker_prompts before update on public.icebreaker_prompts
  for each row execute function app.touch_updated_at();

create or replace function public.draw_icebreaker(p_forum uuid, p_meeting uuid default null)
returns public.icebreaker_prompts
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_cycle  int;
  v_prompt public.icebreaker_prompts;
begin
  if not app.is_forum_member(p_forum) then
    raise exception 'No sos miembro de este foro.' using errcode = '42501';
  end if;

  select coalesce(max(cycle), 1) into v_cycle
  from public.icebreaker_draws where forum_id = p_forum;

  select p.* into v_prompt
  from public.icebreaker_prompts p
  where p.forum_id = p_forum and p.is_active
    and not exists (
      select 1 from public.icebreaker_draws d
      where d.forum_id = p_forum and d.cycle = v_cycle and d.prompt_id = p.id
    )
  order by random()
  limit 1;

  if v_prompt.id is null then
    -- Vuelta agotada: arranca una nueva y se vuelve a sortear entre todos.
    v_cycle := v_cycle + 1;
    select p.* into v_prompt
    from public.icebreaker_prompts p
    where p.forum_id = p_forum and p.is_active
    order by random()
    limit 1;
    if v_prompt.id is null then
      raise exception 'El catalogo de icebreakers esta vacio.' using errcode = '22023';
    end if;
  end if;

  insert into public.icebreaker_draws (forum_id, meeting_id, prompt_id, cycle, drawn_by)
  values (p_forum, p_meeting, v_prompt.id, v_cycle, auth.uid());

  return v_prompt;
end;
$$;

alter table public.icebreaker_prompts enable row level security;
alter table public.icebreaker_draws   enable row level security;

-- El catalogo es del grupo: cualquier miembro agrega y edita.
create policy icebreaker_prompts_select on public.icebreaker_prompts
  for select to authenticated using (app.is_forum_member(forum_id));
create policy icebreaker_prompts_insert on public.icebreaker_prompts
  for insert to authenticated with check (app.is_forum_member(forum_id));
create policy icebreaker_prompts_update on public.icebreaker_prompts
  for update to authenticated using (app.is_forum_member(forum_id)) with check (app.is_forum_member(forum_id));
create policy icebreaker_prompts_delete on public.icebreaker_prompts
  for delete to authenticated using (created_by = auth.uid() or app.is_moderator(forum_id));

create policy icebreaker_draws_select on public.icebreaker_draws
  for select to authenticated using (app.is_forum_member(forum_id));
