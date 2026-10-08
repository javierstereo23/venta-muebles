-- =============================================================================
-- 0011 · El moderador fija la fecha a mano.
--
-- La votacion es el camino habitual, pero no el unico: a veces la fecha se
-- cierra en la sala, por telefono o porque el lugar tiene una sola fecha
-- disponible. En esos casos el moderador la fija y la votacion abierta queda
-- sin efecto (superseded) en vez de quedar colgada esperando un cierre que no
-- va a llegar. Lo que se vota no se pierde: las fechas propuestas y quien podia
-- quedan guardadas.
-- =============================================================================

create or replace function public.schedule_meeting(
  p_forum             uuid,
  p_starts_at         timestamptz,
  p_ends_at           timestamptz default null,
  p_location          text default null,
  p_title             text default null,
  p_meeting           uuid default null,
  p_apply_template    boolean default true,
  p_supersede_polls   boolean default true
)
returns public.meetings
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_row public.meetings;
begin
  if not app.is_moderator(p_forum) then
    raise exception 'Solo el moderador fija la fecha del foro.' using errcode = '42501';
  end if;
  if p_ends_at is not null and p_ends_at <= p_starts_at then
    raise exception 'La reunion no puede terminar antes de empezar.' using errcode = '23514';
  end if;

  if p_meeting is null then
    insert into public.meetings (forum_id, title, scheduled_at, ends_at, location, status, created_by)
    values (
      p_forum,
      coalesce(p_title, 'Foro ' || to_char(p_starts_at, 'TMMonth YYYY')),
      p_starts_at,
      p_ends_at,
      p_location,
      'scheduled',
      auth.uid()
    )
    returning * into v_row;
  else
    update public.meetings
       set scheduled_at = p_starts_at,
           ends_at      = p_ends_at,
           location     = coalesce(p_location, location),
           title        = coalesce(p_title, title),
           status       = case when status = 'draft' then 'scheduled' else status end
     where id = p_meeting and forum_id = p_forum
    returning * into v_row;

    if v_row.id is null then
      raise exception 'Esa reunion no existe en este foro.' using errcode = '22023';
    end if;
  end if;

  -- Agenda cargada, horarios encadenados desde la hora de inicio y hora de fin.
  perform app.apply_meeting_schedule(v_row.id, p_apply_template);

  if p_supersede_polls then
    update public.date_polls
       set status = 'superseded',
           closed_at = now(),
           resulting_meeting_id = v_row.id
     where forum_id = p_forum and kind = 'meeting' and status = 'open';
  end if;

  select * into v_row from public.meetings where id = v_row.id;
  return v_row;
end;
$$;

comment on function public.schedule_meeting is
  'Fija la fecha del proximo foro sin esperar a que cierre la votacion. Solo el '
  'moderador. Deja la agenda base cargada con los horarios ya calculados y la '
  'votacion abierta sin efecto.';
