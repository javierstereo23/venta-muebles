-- =============================================================================
-- 0010 · Endurecimiento de permisos.
-- anon no tiene absolutamente nada: no hay una sola pantalla publica. Todo pasa
-- por authenticated + RLS. Se corre al final para alcanzar a todos los objetos.
-- =============================================================================

revoke all on all tables    in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all routines  in schema public from public;
revoke all on all routines  in schema public from anon;

alter default privileges in schema public revoke all on tables    from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke all on routines  from public, anon;

grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on all routines in schema public to authenticated;

-- La vista de promedios es solo de lectura.
revoke insert, update, delete on public.meeting_feedback_summary from authenticated;

-- Las funciones de app/ nunca se llaman desde el cliente: se usan dentro de las
-- policies, donde el motor las evalua con el rol del que consulta.
revoke all on all routines in schema app from public, anon;
grant execute on all routines in schema app to authenticated;
