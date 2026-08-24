-- =============================================================================
-- Verificacion de RLS y reglas de metodologia contra una base real.
-- Cada bloque cambia de usuario como lo haria PostgREST: rol authenticated +
-- el claim "sub" del JWT.
-- =============================================================================

\set forum   '00000000-0000-4000-8000-000000000001'
\set javier  '11111111-1111-4111-8111-111111111111'
\set esteban '22222222-2222-4222-8222-222222222222'
\set vicky   '33333333-3333-4333-8333-333333333333'
\set ariel   '44444444-4444-4444-8444-444444444444'
\set michael '55555555-5555-4555-8555-555555555555'
\set ref_j   'a1a1a1a1-0000-4000-8000-000000000001'
\set ref_a   'a1a1a1a1-0000-4000-8000-000000000002'

\echo '--- 1. anon no puede leer nada'
begin;
set local role anon;
do $$
begin
  begin
    perform 1 from public.profiles;
    raise exception 'FALLO: anon pudo consultar profiles';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.reflections;
    raise exception 'FALLO: anon pudo consultar reflections';
  exception when insufficient_privilege then null;
  end;
end;
$$;
rollback;
\echo '    ok'

\echo '--- 2. un email fuera de la lista blanca no puede crear cuenta'
do $$
begin
  begin
    insert into auth.users (id, email) values (gen_random_uuid(), 'colado@example.invalid');
    raise exception 'FALLO: se creo una cuenta fuera de la lista blanca';
  exception when insufficient_privilege then null;
  end;
end;
$$;
\echo '    ok'

\echo '--- 3. cada uno carga su 5%'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'javier', true) \g /dev/null
insert into public.reflections (id, forum_id, period_month, outlook_30_60, deep_dive_topic, deep_dive_why, iq_topic)
values (:'ref_j', :'forum', date '2026-08-01', 'Dos meses de cierre de ronda.',
        'Dejamos de hablar de lo que importa con mi socio', 'Porque me estoy guardando cosas hace seis meses.',
        'Como armar un comite de inversion');
update public.reflection_pillars
   set emotions = array['bronca','miedo','culpa'],
       cause = 'Una conversacion que evite tres veces.',
       significance = 'Creci creyendo que pedir ayuda es debilidad.'
 where reflection_id = :'ref_j' and pillar = 'work';
commit;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'ariel', true) \g /dev/null
insert into public.reflections (id, forum_id, period_month, deep_dive_topic, iq_topic)
values (:'ref_a', :'forum', date '2026-08-01', 'Mi hijo mayor se va del pais', 'Elegir un CFO part time');
update public.reflection_pillars
   set emotions = array['tristeza','orgullo','vacio'], cause = 'Se va en noviembre.', significance = 'No se quien soy sin ese rol.'
 where reflection_id = :'ref_a';
commit;
\echo '    ok'

\echo '--- 4. el 5% es privado: ni el moderador lo ve'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'javier', true) \g /dev/null
do $$
begin
  assert (select count(*) from public.reflections) = 1, 'Javier deberia ver solo su propio 5%';
  assert (select count(*) from public.reflections where id = 'a1a1a1a1-0000-4000-8000-000000000002') = 0,
    'FALLO: el moderador pudo leer el 5% de otro miembro';
  assert (select count(*) from public.reflection_pillars) = 3, 'solo los pilares propios';
  -- consulta directa buscando el texto de otro: no devuelve nada
  assert (select count(*) from public.reflection_pillars where significance ilike '%sin ese rol%') = 0,
    'FALLO: se filtro el contenido de otro 5%';
end;
$$;
rollback;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'vicky', true) \g /dev/null
do $$
begin
  assert (select count(*) from public.reflections) = 0, 'FALLO: la moderadora electa vio 5% ajenos';
end;
$$;
rollback;
\echo '    ok'

\echo '--- 5. nadie puede escribir el 5% de otro'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'ariel', true) \g /dev/null
do $$
declare v_rows int;
begin
  update public.reflections set outlook_30_60 = 'hackeado'
   where id = 'a1a1a1a1-0000-4000-8000-000000000001';
  get diagnostics v_rows = row_count;
  assert v_rows = 0, 'FALLO: se pudo editar el 5% de otro';

  delete from public.reflections where id = 'a1a1a1a1-0000-4000-8000-000000000001';
  get diagnostics v_rows = row_count;
  assert v_rows = 0, 'FALLO: se pudo borrar el 5% de otro';

  begin
    insert into public.reflections (forum_id, author_id, period_month)
    values ('00000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', date '2026-07-01');
    raise exception 'FALLO: se pudo crear un 5%% a nombre de otro';
  exception when insufficient_privilege then null;
  end;
end;
$$;
rollback;
\echo '    ok'

\echo '--- 6. finalizar exige 3 a 5 emociones, causa y significado en los tres pilares'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'javier', true) \g /dev/null
do $$
begin
  begin
    perform public.finalize_reflection('a1a1a1a1-0000-4000-8000-000000000001');
    raise exception 'FALLO: finalizo con pilares incompletos';
  exception when check_violation then null;
  end;
end;
$$;
update public.reflection_pillars
   set emotions = array['ansiedad','entusiasmo','duda'], cause = 'Cierre de ronda.', significance = 'Necesito que me vean capaz.'
 where reflection_id = :'ref_j' and pillar in ('family','personal');
do $$
declare v public.reflections;
begin
  v := public.finalize_reflection('a1a1a1a1-0000-4000-8000-000000000001');
  assert v.status = 'final', 'deberia quedar final';
end;
$$;
commit;
\echo '    ok'

\set m1 'bbbb0000-0000-4000-8000-000000000001'
\set m2 'bbbb0000-0000-4000-8000-000000000002'

\echo '--- 7. publicar al Parking Lot copia el titular y nada mas'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'ariel', true) \g /dev/null
do $$
declare it public.parking_lot_items;
begin
  it := public.publish_parking_lot_topic('a1a1a1a1-0000-4000-8000-000000000002', 'eq', 8);
  assert it.headline = 'Mi hijo mayor se va del pais', 'el titular deberia venir del 5%';
  assert it.quadrant = 'q2', 'un Deep Dive vive en Q2';
  it := public.publish_parking_lot_topic('a1a1a1a1-0000-4000-8000-000000000002', 'iq', 4);
  assert it.quadrant = 'q1' and it.kind = 'iq', 'el tema IQ vive en Q1';
end;
$$;
commit;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'javier', true) \g /dev/null
select public.publish_parking_lot_topic(:'ref_j', 'eq', 9) \g /dev/null
commit;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'michael', true) \g /dev/null
do $$
begin
  assert (select count(*) from public.parking_lot_items) = 3, 'el foro entero ve los titulares publicados';
  -- lo unico visible es el titular: ningun campo del 5% viaja a esta tabla
  assert (select count(*) from public.parking_lot_items where headline ilike '%sin ese rol%') = 0,
    'FALLO: se filtro contenido del 5%';
  assert (select count(*) from public.reflections) = 0, 'un miembro sin 5% cargado no ve ninguno';
end;
$$;
rollback;
\echo '    ok'

\echo '--- 8. la moderadora electa ordena, pero no reescribe el tema de otro'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'vicky', true) \g /dev/null
do $$
declare v_rows int;
begin
  update public.parking_lot_items set position = 1, status = 'scheduled'
   where author_id = '44444444-4444-4444-8444-444444444444' and kind = 'eq';
  get diagnostics v_rows = row_count;
  assert v_rows = 1, 'la moderadora electa deberia poder ordenar y agendar';

  begin
    update public.parking_lot_items set headline = 'otro tema'
     where author_id = '44444444-4444-4444-8444-444444444444' and kind = 'eq';
    raise exception 'FALLO: la moderadora electa reescribio el tema de otro';
  exception when insufficient_privilege then null;
  end;

  begin
    update public.parking_lot_items set weight = 1
     where author_id = '44444444-4444-4444-8444-444444444444' and kind = 'eq';
    raise exception 'FALLO: la moderadora electa cambio el peso de otro';
  exception when insufficient_privilege then null;
  end;
end;
$$;
rollback;
\echo '    ok'

\echo '--- 9. agenda y cronometro: solo el moderador'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'javier', true) \g /dev/null
insert into public.meetings (id, forum_id, scheduled_at, location, status)
values (:'m1', :'forum', timestamptz '2026-09-10 19:00-03', 'Casa de Ariel', 'scheduled'),
       (:'m2', :'forum', timestamptz '2026-07-09 19:00-03', 'Oficina de Vicky', 'closed');
select public.apply_agenda_template(:'m1') \g /dev/null
do $$
begin
  assert (select count(*) from public.agenda_blocks where meeting_id = 'bbbb0000-0000-4000-8000-000000000001') = 8,
    'la plantilla base carga 8 bloques';
  assert (select sum(duration_minutes) from public.agenda_blocks
          where meeting_id = 'bbbb0000-0000-4000-8000-000000000001') = 240,
    'la plantilla base suma 240 minutos: cuatro horas exactas con los dos breaks';
  assert (select count(*) from public.agenda_blocks
          where meeting_id = 'bbbb0000-0000-4000-8000-000000000001' and kind = 'eq') = 3,
    'tres bloques EQ';
  assert (select count(*) from public.agenda_blocks
          where meeting_id = 'bbbb0000-0000-4000-8000-000000000001' and kind = 'iq') = 1,
    'un bloque IQ, separado del EQ';
end;
$$;
commit;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'michael', true) \g /dev/null
do $$
declare v_rows int; v_block uuid;
begin
  select id into v_block from public.agenda_blocks
   where meeting_id = 'bbbb0000-0000-4000-8000-000000000001' and position = 1;
  assert v_block is not null, 'un miembro deberia poder leer la agenda';

  update public.agenda_blocks set duration_minutes = 5 where id = v_block;
  get diagnostics v_rows = row_count;
  assert v_rows = 0, 'FALLO: un miembro edito la agenda';

  begin
    perform public.timer_start(v_block);
    raise exception 'FALLO: un miembro arranco el cronometro';
  exception when insufficient_privilege then null;
  end;
end;
$$;
rollback;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'javier', true) \g /dev/null
do $$
declare v_block uuid; v_row public.agenda_blocks;
begin
  select id into v_block from public.agenda_blocks
   where meeting_id = 'bbbb0000-0000-4000-8000-000000000001' and position = 1;
  v_row := public.timer_start(v_block);
  assert v_row.timer_status = 'running' and v_row.timer_started_at is not null, 'deberia arrancar';
  perform pg_sleep(1.1);
  v_row := public.timer_pause(v_block);
  assert v_row.timer_status = 'paused', 'deberia pausar';
  assert v_row.timer_elapsed_seconds >= 1, 'deberia acumular el tiempo corrido en el servidor';
  v_row := public.timer_reset(v_block);
  assert v_row.timer_elapsed_seconds = 0 and v_row.timer_status = 'idle', 'deberia reiniciar';
end;
$$;
rollback;
\echo '    ok'

\set poll 'cccc0000-0000-4000-8000-000000000001'

\echo '--- 10. votacion de fechas: minimo 5 candidatas y cierre solo del moderador'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'javier', true) \g /dev/null
insert into public.date_polls (id, forum_id, kind, title, target_month)
values (:'poll', :'forum', 'meeting', 'Foro de octubre', date '2026-10-01');
commit;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'ariel', true) \g /dev/null
insert into public.date_poll_options (poll_id, proposed_on, starts_at) values
  (:'poll', date '2026-10-06', time '19:00'),
  (:'poll', date '2026-10-08', time '19:00'),
  (:'poll', date '2026-10-13', time '19:00'),
  (:'poll', date '2026-10-15', time '19:00');
commit;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'javier', true) \g /dev/null
do $$
begin
  begin
    perform public.close_date_poll('cccc0000-0000-4000-8000-000000000001');
    raise exception 'FALLO: cerro la votacion con menos de 5 fechas';
  exception when check_violation then null;
  end;
end;
$$;
commit;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'michael', true) \g /dev/null
insert into public.date_poll_options (poll_id, proposed_on, starts_at)
values (:'poll', date '2026-10-20', time '19:00');
-- todos disponibles el 13, dos el resto
insert into public.date_poll_votes (option_id, is_available)
select id, proposed_on = date '2026-10-13' from public.date_poll_options where poll_id = :'poll';
commit;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'ariel', true) \g /dev/null
insert into public.date_poll_votes (option_id, is_available)
select id, proposed_on in (date '2026-10-13', date '2026-10-20') from public.date_poll_options where poll_id = :'poll';
do $$
begin
  begin
    perform public.close_date_poll('cccc0000-0000-4000-8000-000000000001');
    raise exception 'FALLO: un miembro cerro la votacion';
  exception when insufficient_privilege then null;
  end;
end;
$$;
commit;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'javier', true) \g /dev/null
do $$
declare p public.date_polls; v_when timestamptz;
begin
  p := public.close_date_poll('cccc0000-0000-4000-8000-000000000001', 'Casa de Michael');
  assert p.status = 'closed', 'deberia quedar cerrada';
  assert (select proposed_on from public.date_poll_options where id = p.winning_option_id) = date '2026-10-13',
    'deberia ganar la fecha con mas disponibles';
  select scheduled_at into v_when from public.meetings where id = p.resulting_meeting_id;
  assert v_when is not null, 'el cierre deberia crear la proxima reunion';
  assert (select count(*) from public.agenda_blocks where meeting_id = p.resulting_meeting_id) = 8,
    'la reunion nueva deberia nacer con la agenda base';
end;
$$;
rollback;
\echo '    ok'

\echo '--- 11. puntajes: lo del celular es anonimo, lo de la sala lleva nombre'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'michael', true) \g /dev/null
insert into public.meeting_feedback (meeting_id, overall_score, one_point_better, connection, personal_growth, business_takeaways)
values (:'m2', 9, 'Arrancar puntual.', 9, 8, 7);
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'ariel', true) \g /dev/null
insert into public.meeting_feedback (meeting_id, overall_score, one_point_better, connection, personal_growth, business_takeaways)
values (:'m2', 7, 'Menos IQ, mas EQ.', 8, 7, 6);
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'vicky', true) \g /dev/null
insert into public.meeting_feedback (meeting_id, overall_score, one_point_better, connection, personal_growth, business_takeaways)
values (:'m2', 8, 'Cortar los desbordes de tiempo.', 10, 9, 5);
commit;

\echo '     · un miembro no puede anotar el puntaje de otro'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'ariel', true) \g /dev/null
do $$
begin
  begin
    insert into public.meeting_feedback (meeting_id, member_id, source, recorded_by, overall_score)
    values ('bbbb0000-0000-4000-8000-000000000002', '55555555-5555-4555-8555-555555555555',
            'room', '44444444-4444-4444-8444-444444444444', 2);
    raise exception 'FALLO: un miembro anoto el puntaje de otro';
  exception when insufficient_privilege then null;
  end;
end;
$$;
rollback;

\echo '     · quien modera anota la ronda en voz alta'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'javier', true) \g /dev/null
insert into public.meeting_feedback (meeting_id, member_id, source, recorded_by, overall_score, one_point_better, connection, personal_growth, business_takeaways)
values (:'m1', :'esteban', 'room', :'javier', 6, 'Mas tiempo de Deep Dive.', 7, 6, 5),
       (:'m1', :'vicky',   'room', :'javier', 9, 'Nada, estuvo muy bien.',   9, 9, 8);
insert into public.meeting_feedback (meeting_id, overall_score, one_point_better, connection, personal_growth, business_takeaways)
values (:'m1', 8, 'Empezar en hora.', 8, 8, 8);
do $$
begin
  begin
    insert into public.meeting_feedback (meeting_id, member_id, source, recorded_by, overall_score)
    values ('bbbb0000-0000-4000-8000-000000000002', '55555555-5555-4555-8555-555555555555',
            'room', '11111111-1111-4111-8111-111111111111', 3);
    raise exception 'FALLO: se piso un puntaje ya cargado desde el celular';
  exception when unique_violation then null;
  end;
end;
$$;
commit;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'esteban', true) \g /dev/null
do $$
declare s record;
begin
  -- del celular solo se ve el propio; de la sala se ve todo
  assert (select count(*) from public.meeting_feedback
           where meeting_id = 'bbbb0000-0000-4000-8000-000000000002') = 0,
    'FALLO: se leyeron puntajes anonimos de otros';
  assert (select count(*) from public.meeting_feedback
           where meeting_id = 'bbbb0000-0000-4000-8000-000000000001') = 2,
    'de la reunion de julio: su propia fila de sala y la de Vicky, ambas dichas en voz alta';
  assert (select count(*) from public.meeting_feedback
           where meeting_id = 'bbbb0000-0000-4000-8000-000000000001' and source = 'self') = 0,
    'FALLO: se leyo el puntaje que otro cargo desde el celular';

  select * into s from public.meeting_feedback_summary where meeting_id = 'bbbb0000-0000-4000-8000-000000000002';
  assert s.respondents = 3, 'el foro ve cuantos respondieron';
  assert s.avg_overall = 8.00, 'el foro ve el promedio, no las filas';
  assert s.avg_connection = 9.00, 'promedio de conexion';

  assert (select count(*) from public.meeting_feedback_notes('bbbb0000-0000-4000-8000-000000000002')) = 3,
    'los comentarios del celular se leen, sin autor';
  assert (select count(*) from public.meeting_feedback_notes('bbbb0000-0000-4000-8000-000000000002')
           where author is not null) = 0,
    'FALLO: un comentario anonimo salio con nombre';
  assert (select count(*) from public.meeting_feedback_notes('bbbb0000-0000-4000-8000-000000000001')
           where author is not null) = 2,
    'los comentarios dichos en la sala se leen con nombre';

  assert (select count(*) from public.meeting_feedback_responded
           where meeting_id = 'bbbb0000-0000-4000-8000-000000000002') = 3,
    'quien toma nota ve quien ya respondio, sin ver que puso';
end;
$$;
rollback;
\echo '    ok'

\echo '--- 12. el icebreaker no repite hasta agotar la lista'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'javier', true) \g /dev/null
do $$
declare i int; p public.icebreaker_prompts; v_total int;
begin
  select count(*) into v_total from public.icebreaker_prompts where forum_id = '00000000-0000-4000-8000-000000000001';
  for i in 1 .. v_total loop
    p := public.draw_icebreaker('00000000-0000-4000-8000-000000000001');
  end loop;
  assert (select count(distinct prompt_id) from public.icebreaker_draws where cycle = 1) = v_total,
    'la primera vuelta deberia recorrer todos los disparadores sin repetir';
  p := public.draw_icebreaker('00000000-0000-4000-8000-000000000001');
  assert (select max(cycle) from public.icebreaker_draws) = 2, 'agotada la lista, arranca una vuelta nueva';
end;
$$;
rollback;
\echo '    ok'

\echo '--- 13. fotos de perfil: cada uno sube a su carpeta, el foro las ve'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'javier', true) \g /dev/null
insert into storage.objects (bucket_id, name, owner)
values ('avatars', '11111111-1111-4111-8111-111111111111/foto.png', :'javier');
do $$
begin
  begin
    insert into storage.objects (bucket_id, name, owner)
    values ('avatars', '44444444-4444-4444-8444-444444444444/foto.png', '11111111-1111-4111-8111-111111111111');
    raise exception 'FALLO: se pudo escribir en la carpeta de otro';
  exception when insufficient_privilege then null;
  end;
end;
$$;
commit;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'ariel', true) \g /dev/null
do $$
begin
  assert (select count(*) from storage.objects where bucket_id = 'avatars') = 1,
    'las fotos del foro se ven entre miembros';
end;
$$;
rollback;
\echo '    ok'


\set vecino '66666666-6666-4666-8666-666666666666'

\echo '--- 14. nadie se autoasciende de rol'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'ariel', true) \g /dev/null
do $$
begin
  begin
    update public.profiles set role = 'moderator' where id = '44444444-4444-4444-8444-444444444444';
    raise exception 'FALLO: un miembro se cambio el rol solo';
  exception when insufficient_privilege then null;
  end;
  update public.profiles set full_name = 'Ariel A.' where id = '44444444-4444-4444-8444-444444444444';
  assert (select full_name from public.profiles where id = '44444444-4444-4444-8444-444444444444') = 'Ariel A.',
    'el nombre propio si se puede editar';
end;
$$;
rollback;
\echo '    ok'

\echo '--- 15. un foro no ve nada del otro'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'vecino', true) \g /dev/null
do $$
begin
  assert (select count(*) from public.profiles
           where forum_id = '00000000-0000-4000-8000-000000000001') = 0, 'FALLO: vio perfiles de otro foro';
  assert (select count(*) from public.profiles) = 1, 'solo deberia verse a si mismo';
  assert (select count(*) from public.parking_lot_items) = 0, 'FALLO: vio el Parking Lot de otro foro';
  assert (select count(*) from public.meetings) = 0, 'FALLO: vio reuniones de otro foro';
  assert (select count(*) from public.meeting_feedback_summary) = 0, 'FALLO: vio promedios de otro foro';
  assert (select count(*) from public.icebreaker_prompts) = 0, 'FALLO: vio el catalogo de otro foro';
  begin
    perform public.meeting_feedback_notes('bbbb0000-0000-4000-8000-000000000002');
    raise exception 'FALLO: leyo comentarios de otro foro';
  exception when insufficient_privilege then null;
  end;
end;
$$;
rollback;
\echo '    ok'

\echo ''
\echo 'TODOS LOS CHEQUEOS PASARON'
