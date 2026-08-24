-- =============================================================================
-- Fixtures de test: cinco altas reales pasando por el trigger de lista blanca.
-- =============================================================================

insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'javier@dynamo.tech'),
  ('22222222-2222-4222-8222-222222222222', 'esteban.oliva@example.invalid'),
  ('33333333-3333-4333-8333-333333333333', 'victoria.costapaz@example.invalid'),
  ('44444444-4444-4444-8444-444444444444', 'ariel.arrieta@example.invalid'),
  ('55555555-5555-4555-8555-555555555555', 'michael.gibert@example.invalid');

-- Victoria queda como moderadora electa para probar los permisos de curaduria.
update public.profiles set role = 'moderator_elect'
where id = '33333333-3333-4333-8333-333333333333';

do $$
begin
  assert (select count(*) from public.profiles) = 5, 'deberian haberse creado 5 perfiles';
  assert (select role from public.profiles where id = '11111111-1111-4111-8111-111111111111') = 'moderator',
    'Javier deberia ser moderador segun la lista blanca';
  assert (select role from public.profiles where id = '22222222-2222-4222-8222-222222222222') = 'moderator_outgoing',
    'Esteban deberia quedar como moderador saliente';
end;
$$;

-- Segundo foro, para verificar el aislamiento entre foros que exige el modelo
-- multi-foro (modelado en fase 1, sin UI).
insert into public.forums (id, name, chapter)
values ('00000000-0000-4000-8000-000000000002', 'Foro EO Vecino', 'Buenos Aires');

insert into public.member_allowlist (forum_id, email, full_name, role)
values ('00000000-0000-4000-8000-000000000002', 'vecino@example.invalid', 'Miembro Vecino', 'moderator');

insert into auth.users (id, email)
values ('66666666-6666-4666-8666-666666666666', 'vecino@example.invalid');
