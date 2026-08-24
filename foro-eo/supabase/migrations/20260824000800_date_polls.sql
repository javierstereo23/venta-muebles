-- =============================================================================
-- 0008 · Votacion de fechas (reunion mensual y retreat anual).
-- =============================================================================

create table public.date_polls (
  id                uuid primary key default gen_random_uuid(),
  forum_id          uuid not null references public.forums(id) on delete cascade,
  kind              public.poll_kind not null default 'meeting',
  title             text,
  target_month      date,
  status            public.poll_status not null default 'open',
  min_options       int not null default 5 check (min_options >= 1),
  created_by        uuid references public.profiles(id) on delete set null,
  created_at        timestamptz not null default now(),
  closed_at         timestamptz,
  winning_option_id uuid,
  resulting_meeting_id uuid references public.meetings(id) on delete set null
);
create index on public.date_polls (forum_id, status);

create table public.date_poll_options (
  id          uuid primary key default gen_random_uuid(),
  poll_id     uuid not null references public.date_polls(id) on delete cascade,
  proposed_on date not null,
  starts_at   time,
  note        text,
  proposed_by uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  constraint date_poll_options_unique unique nulls not distinct (poll_id, proposed_on, starts_at)
);

alter table public.date_polls
  add constraint date_polls_winner_fk
  foreign key (winning_option_id) references public.date_poll_options(id) on delete set null;

create table public.date_poll_votes (
  id           uuid primary key default gen_random_uuid(),
  option_id    uuid not null references public.date_poll_options(id) on delete cascade,
  voter_id     uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  is_available boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint date_poll_votes_unique unique (option_id, voter_id)
);
comment on table public.date_poll_votes is
  'La disponibilidad NO es anonima: coordinar una fecha requiere saber quien puede. '
  'Lo anonimo son los puntajes de la reunion (ver meeting_feedback).';

create trigger touch_votes before update on public.date_poll_votes
  for each row execute function app.touch_updated_at();

create or replace function public.close_date_poll(
  p_poll     uuid,
  p_location text default null,
  p_apply_template boolean default true
)
returns public.date_polls
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_poll    public.date_polls;
  v_options int;
  v_winner  public.date_poll_options;
  v_meeting uuid;
begin
  select * into v_poll from public.date_polls where id = p_poll;
  if v_poll.id is null then
    raise exception 'No existe esa votacion.' using errcode = '22023';
  end if;
  if not app.is_moderator(v_poll.forum_id) then
    raise exception 'Solo el moderador cierra una votacion.' using errcode = '42501';
  end if;
  if v_poll.status = 'closed' then
    raise exception 'Esa votacion ya esta cerrada.' using errcode = '23505';
  end if;

  select count(*) into v_options from public.date_poll_options where poll_id = p_poll;
  if v_options < v_poll.min_options then
    raise exception 'Hacen falta al menos % fechas candidatas y hay %.', v_poll.min_options, v_options
      using errcode = '23514';
  end if;

  -- Gana la fecha con mas disponibles; empate: la mas temprana.
  select o.* into v_winner
  from public.date_poll_options o
  left join public.date_poll_votes v on v.option_id = o.id and v.is_available
  where o.poll_id = p_poll
  group by o.id
  order by count(v.id) desc, o.proposed_on asc, o.starts_at asc nulls last, o.created_at asc
  limit 1;

  if v_poll.kind = 'meeting' then
    insert into public.meetings (forum_id, title, scheduled_at, location, status, created_by)
    values (
      v_poll.forum_id,
      coalesce(v_poll.title, 'Foro ' || to_char(v_winner.proposed_on, 'TMMonth YYYY')),
      (v_winner.proposed_on + coalesce(v_winner.starts_at, time '19:00'))::timestamptz,
      p_location,
      'scheduled',
      auth.uid()
    )
    returning id into v_meeting;

    if p_apply_template then
      perform public.apply_agenda_template(v_meeting);
    end if;
  else
    update public.forums set next_retreat_on = v_winner.proposed_on where id = v_poll.forum_id;
  end if;

  update public.date_polls
     set status = 'closed',
         closed_at = now(),
         winning_option_id = v_winner.id,
         resulting_meeting_id = v_meeting
   where id = p_poll
  returning * into v_poll;

  return v_poll;
end;
$$;

alter table public.date_polls        enable row level security;
alter table public.date_poll_options enable row level security;
alter table public.date_poll_votes   enable row level security;

create policy date_polls_select on public.date_polls
  for select to authenticated using (app.is_forum_member(forum_id));
create policy date_polls_write on public.date_polls
  for all to authenticated using (app.is_moderator(forum_id)) with check (app.is_moderator(forum_id));

create policy date_poll_options_select on public.date_poll_options
  for select to authenticated
  using (exists (select 1 from public.date_polls p where p.id = poll_id and app.is_forum_member(p.forum_id)));
create policy date_poll_options_insert on public.date_poll_options
  for insert to authenticated
  with check (
    proposed_by = auth.uid()
    and exists (select 1 from public.date_polls p
                where p.id = poll_id and p.status = 'open' and app.is_forum_member(p.forum_id))
  );
create policy date_poll_options_delete on public.date_poll_options
  for delete to authenticated
  using (
    (proposed_by = auth.uid()
       or exists (select 1 from public.date_polls p where p.id = poll_id and app.is_moderator(p.forum_id)))
    and not exists (select 1 from public.date_poll_votes v where v.option_id = date_poll_options.id)
  );

create policy date_poll_votes_select on public.date_poll_votes
  for select to authenticated
  using (exists (
    select 1 from public.date_poll_options o join public.date_polls p on p.id = o.poll_id
    where o.id = option_id and app.is_forum_member(p.forum_id)
  ));
create policy date_poll_votes_write on public.date_poll_votes
  for all to authenticated
  using (voter_id = auth.uid())
  with check (
    voter_id = auth.uid()
    and exists (
      select 1 from public.date_poll_options o join public.date_polls p on p.id = o.poll_id
      where o.id = option_id and p.status = 'open' and app.is_forum_member(p.forum_id)
    )
  );
