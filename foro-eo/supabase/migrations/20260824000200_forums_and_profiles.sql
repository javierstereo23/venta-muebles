-- =============================================================================
-- 0002 · Foro, valores, lista blanca de miembros, perfiles y helpers de RLS.
-- =============================================================================

create table public.forums (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  chapter         text,
  purpose         text,
  next_retreat_on date,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
comment on column public.forums.purpose is
  'Proposito del foro. Editable por el moderador; es el norte del producto.';

create table public.forum_values (
  id         uuid primary key default gen_random_uuid(),
  forum_id   uuid not null references public.forums(id) on delete cascade,
  label      text not null,
  body       text,
  position   int  not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.forum_values (forum_id, position);

-- Lista blanca: unica puerta de entrada. Sin fila aca no hay cuenta posible.
create table public.member_allowlist (
  id              uuid primary key default gen_random_uuid(),
  forum_id        uuid not null references public.forums(id) on delete cascade,
  email           citext not null unique,
  full_name       text not null,
  role            public.forum_role not null default 'member',
  joined_forum_on date,
  invited_at      timestamptz not null default now(),
  revoked_at      timestamptz
);

create table public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  forum_id        uuid not null references public.forums(id) on delete restrict,
  email           citext not null unique,
  full_name       text not null,
  avatar_path     text,
  role            public.forum_role not null default 'member',
  joined_forum_on date,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index on public.profiles (forum_id);
comment on column public.profiles.avatar_path is
  'Ruta dentro del bucket privado "avatars": <user_id>/<archivo>. Nunca una URL publica.';

create trigger touch_forums        before update on public.forums        for each row execute function app.touch_updated_at();
create trigger touch_forum_values  before update on public.forum_values  for each row execute function app.touch_updated_at();
create trigger touch_profiles      before update on public.profiles      for each row execute function app.touch_updated_at();

-- -----------------------------------------------------------------------------
-- Helpers de autorizacion (SECURITY DEFINER: leen profiles saltando RLS, lo que
-- evita la recursion "policy de profiles -> consulta profiles -> policy ...").
-- -----------------------------------------------------------------------------

create or replace function app.my_forum_id()
returns uuid language sql stable security definer set search_path = public, pg_temp as $$
  select p.forum_id from public.profiles p where p.id = auth.uid() and p.is_active
$$;

create or replace function app.my_role()
returns public.forum_role language sql stable security definer set search_path = public, pg_temp as $$
  select p.role from public.profiles p where p.id = auth.uid() and p.is_active
$$;

create or replace function app.is_forum_member(p_forum uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_active and p.forum_id = p_forum
  )
$$;

create or replace function app.is_moderator(p_forum uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_active and p.forum_id = p_forum and p.role = 'moderator'
  )
$$;

create or replace function app.is_moderator_elect(p_forum uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_active and p.forum_id = p_forum and p.role = 'moderator_elect'
  )
$$;

-- Curaduria del Parking Lot y orden de los Deep Dives del anio.
create or replace function app.can_curate(p_forum uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_active and p.forum_id = p_forum
      and p.role in ('moderator', 'moderator_elect')
  )
$$;

create or replace function app.profile_forum(p_user uuid)
returns uuid language sql stable security definer set search_path = public, pg_temp as $$
  select p.forum_id from public.profiles p where p.id = p_user
$$;

-- Solo authenticated puede siquiera resolver el esquema app.
revoke usage on schema app from public;
grant  usage on schema app to authenticated;

-- -----------------------------------------------------------------------------
-- Alta de usuario: la lista blanca se aplica en la base, no en la UI.
-- -----------------------------------------------------------------------------

create or replace function app.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  wl public.member_allowlist;
begin
  select * into wl
  from public.member_allowlist
  where email = new.email and revoked_at is null;

  if wl.id is null then
    raise exception 'El email % no esta autorizado en este foro.', new.email
      using errcode = '42501';
  end if;

  insert into public.profiles (id, forum_id, email, full_name, role, joined_forum_on)
  values (new.id, wl.forum_id, new.email, wl.full_name, wl.role, wl.joined_forum_on)
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function app.handle_new_user();

-- Rol, foro, email e id de un perfil no los cambia el propio usuario.
create or replace function app.protect_profile_columns()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then
    return new;  -- migraciones / seed / service_role
  end if;
  if (new.role      is distinct from old.role
   or new.forum_id  is distinct from old.forum_id
   or new.email     is distinct from old.email
   or new.id        is distinct from old.id
   or new.is_active is distinct from old.is_active)
   and not app.is_moderator(old.forum_id) then
    raise exception 'Solo el moderador puede cambiar rol, foro, email o alta/baja de un perfil.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger protect_profile_columns
  before update on public.profiles
  for each row execute function app.protect_profile_columns();

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------

alter table public.forums           enable row level security;
alter table public.forum_values     enable row level security;
alter table public.member_allowlist enable row level security;
alter table public.profiles         enable row level security;

-- forums: lectura para los miembros, edicion solo moderador. Alta/baja de foros
-- queda fuera de la API (fase 1 = un solo foro).
create policy forums_select on public.forums
  for select to authenticated using (app.is_forum_member(id));
create policy forums_update on public.forums
  for update to authenticated using (app.is_moderator(id)) with check (app.is_moderator(id));

-- Los valores del foro los edita el grupo entero (son del grupo, no del moderador).
create policy forum_values_select on public.forum_values
  for select to authenticated using (app.is_forum_member(forum_id));
create policy forum_values_insert on public.forum_values
  for insert to authenticated with check (app.is_forum_member(forum_id));
create policy forum_values_update on public.forum_values
  for update to authenticated using (app.is_forum_member(forum_id)) with check (app.is_forum_member(forum_id));
create policy forum_values_delete on public.forum_values
  for delete to authenticated using (app.is_forum_member(forum_id));

-- La lista blanca solo la ve y la toca el moderador.
create policy allowlist_select on public.member_allowlist
  for select to authenticated using (app.is_moderator(forum_id));
create policy allowlist_write on public.member_allowlist
  for all to authenticated using (app.is_moderator(forum_id)) with check (app.is_moderator(forum_id));

-- Perfiles: todos los del foro se ven entre si (Inicio muestra a los ocho).
create policy profiles_select on public.profiles
  for select to authenticated using (app.is_forum_member(forum_id));
create policy profiles_update_self on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_update_moderator on public.profiles
  for update to authenticated using (app.is_moderator(forum_id)) with check (app.is_moderator(forum_id));
-- Sin INSERT ni DELETE para authenticated: las altas pasan solo por el trigger.
