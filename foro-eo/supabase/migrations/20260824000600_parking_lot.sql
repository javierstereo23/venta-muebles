-- =============================================================================
-- 0006 · Parking Lot.
-- Una fila por tema publicado. El titular se COPIA desde el 5%; la fila no
-- expone ninguna otra cosa de la reflexion. Borrar el 5% no borra el titular ya
-- publicado (reflection_id queda en null), y publicar nunca arrastra el cuerpo.
-- =============================================================================

create table public.parking_lot_items (
  id                  uuid primary key default gen_random_uuid(),
  forum_id            uuid not null references public.forums(id) on delete cascade,
  author_id           uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  reflection_id       uuid references public.reflections(id) on delete set null,
  kind                public.topic_kind not null,
  quadrant            public.quadrant not null,
  headline            text not null check (btrim(headline) <> ''),
  weight              int not null default 5 check (weight between 1 and 10),
  status              public.parking_status not null default 'open',
  scheduled_meeting_id uuid references public.meetings(id) on delete set null,
  position            int not null default 0,
  published_at        timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index on public.parking_lot_items (forum_id, status, position);
-- Un tema EQ y uno IQ por reflexion: publicar dos veces actualiza, no duplica.
create unique index parking_lot_one_per_reflection_kind
  on public.parking_lot_items (reflection_id, kind) where reflection_id is not null;

create trigger touch_parking_lot before update on public.parking_lot_items
  for each row execute function app.touch_updated_at();

-- El moderador electo ordena y agenda, pero no reescribe el tema de otro.
create or replace function app.parking_lot_curator_guard()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or auth.uid() = old.author_id then
    return new;
  end if;
  if new.headline is distinct from old.headline
     or new.weight    is distinct from old.weight
     or new.kind      is distinct from old.kind
     or new.author_id is distinct from old.author_id
     or new.reflection_id is distinct from old.reflection_id then
    raise exception 'El titular, el peso y el tipo de un tema solo los cambia su autor.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger parking_lot_curator_guard
  before update on public.parking_lot_items
  for each row execute function app.parking_lot_curator_guard();

-- Unica via de publicacion: copia el titular elegido y nada mas.
create or replace function public.publish_parking_lot_topic(
  p_reflection uuid,
  p_kind       public.topic_kind,
  p_weight     int default 5,
  p_quadrant   public.quadrant default null
)
returns public.parking_lot_items
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_ref      public.reflections;
  v_headline text;
  v_quadrant public.quadrant;
  v_row      public.parking_lot_items;
begin
  select * into v_ref from public.reflections where id = p_reflection;
  if v_ref.id is null or v_ref.author_id <> auth.uid() then
    raise exception 'No existe ese 5%% o no es tuyo.' using errcode = '42501';
  end if;

  v_headline := btrim(case when p_kind = 'eq' then v_ref.deep_dive_topic else v_ref.iq_topic end);
  if coalesce(v_headline, '') = '' then
    raise exception 'Todavia no cargaste el tema % en tu 5%%.', p_kind using errcode = '23514';
  end if;

  v_quadrant := coalesce(p_quadrant, case when p_kind = 'eq' then 'q2' else 'q1' end::public.quadrant);

  insert into public.parking_lot_items
    (forum_id, author_id, reflection_id, kind, quadrant, headline, weight)
  values
    (v_ref.forum_id, v_ref.author_id, v_ref.id, p_kind, v_quadrant, v_headline, p_weight)
  on conflict (reflection_id, kind) where reflection_id is not null do update
    set headline = excluded.headline,
        weight   = excluded.weight,
        quadrant = excluded.quadrant,
        published_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------

alter table public.parking_lot_items enable row level security;

create policy parking_lot_select on public.parking_lot_items
  for select to authenticated using (app.is_forum_member(forum_id));
create policy parking_lot_insert on public.parking_lot_items
  for insert to authenticated
  with check (author_id = auth.uid() and app.is_forum_member(forum_id));
create policy parking_lot_update_author on public.parking_lot_items
  for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy parking_lot_update_curator on public.parking_lot_items
  for update to authenticated using (app.can_curate(forum_id)) with check (app.can_curate(forum_id));
create policy parking_lot_delete on public.parking_lot_items
  for delete to authenticated using (author_id = auth.uid() or app.can_curate(forum_id));
