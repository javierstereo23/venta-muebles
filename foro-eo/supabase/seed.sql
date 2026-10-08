-- =============================================================================
-- Seed inicial. Idempotente: se puede correr mas de una vez.
-- NO crea perfiles: los perfiles nacen cuando la persona entra con su magic link
-- y el trigger de la lista blanca los da de alta.
-- =============================================================================

insert into public.forums (id, name, chapter, purpose)
values (
  '00000000-0000-4000-8000-000000000001',
  'Foro EO Buenos Aires',
  'Buenos Aires',
  'Que cada foro sea una experiencia que te transforme y te eleve: como persona, '
  'como emprendedor, como pareja, en cada rol que te importa.'
)
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Lista blanca. OJO: los emails con @example.invalid son marcadores de posicion
-- (ese dominio no puede recibir mail, asi que no habilitan a nadie). Reemplazar
-- por los reales antes de invitar al foro.
-- -----------------------------------------------------------------------------
insert into public.member_allowlist (forum_id, email, full_name, role) values
  ('00000000-0000-4000-8000-000000000001', 'javier@dynamo.tech',                  'Javier Badaracco',  'moderator'),
  ('00000000-0000-4000-8000-000000000001', 'esteban.oliva@example.invalid',       'Esteban Oliva',     'moderator_outgoing'),
  ('00000000-0000-4000-8000-000000000001', 'victoria.costapaz@example.invalid',   'Victoria Costa Paz','member'),
  ('00000000-0000-4000-8000-000000000001', 'anton.chalbaud@example.invalid',      'Anton Chalbaud',    'member'),
  ('00000000-0000-4000-8000-000000000001', 'daniel.czaplinski@example.invalid',   'Daniel Czaplinski', 'member'),
  ('00000000-0000-4000-8000-000000000001', 'michael.gibert@example.invalid',      'Michael Gibert',    'member'),
  ('00000000-0000-4000-8000-000000000001', 'facundo.santana@example.invalid',     'Facundo Santana',   'member'),
  ('00000000-0000-4000-8000-000000000001', 'ariel.arrieta@example.invalid',       'Ariel Arrieta',     'member')
on conflict (email) do nothing;

-- -----------------------------------------------------------------------------
-- Catalogo inicial de icebreakers (editable por el foro).
-- -----------------------------------------------------------------------------
insert into public.icebreaker_prompts (forum_id, text)
select '00000000-0000-4000-8000-000000000001', t
from (values
  ('Trae un objeto de tu infancia y contanos por que sobrevivio.'),
  ('Una foto que no le mostraste a nadie.'),
  ('Algo que alguien te regalo y todavia usas.'),
  ('Meditacion guiada de cinco minutos.'),
  ('La cancion que te acompaño este mes.'),
  ('Una palabra con la que llegas hoy.')
) as s(t)
where not exists (
  select 1 from public.icebreaker_prompts p
  where p.forum_id = '00000000-0000-4000-8000-000000000001' and p.text = s.t
);

-- -----------------------------------------------------------------------------
-- Proxima reunion ya fijada por el moderador: lunes 2 de noviembre de 2026,
-- 16 a 20, en Hit Polo. Se carga con la agenda base y los horarios encadenados.
-- -----------------------------------------------------------------------------
do $$
declare
  v_forum   uuid := '00000000-0000-4000-8000-000000000001';
  v_inicio  timestamptz := timestamptz '2026-11-02 16:00-03';
  v_meeting uuid;
begin
  select id into v_meeting
  from public.meetings
  where forum_id = v_forum and scheduled_at = v_inicio;

  if v_meeting is null then
    insert into public.meetings (forum_id, title, scheduled_at, ends_at, location, status)
    values (v_forum, 'Foro de noviembre', v_inicio, timestamptz '2026-11-02 20:00-03',
            'Hit Polo', 'scheduled')
    returning id into v_meeting;

    perform app.apply_meeting_schedule(v_meeting, true);
  end if;
end;
$$;
