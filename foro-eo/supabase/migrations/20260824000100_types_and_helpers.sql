-- =============================================================================
-- 0001 · Extensiones, esquema privado, tipos y utilidades comunes.
-- =============================================================================

create extension if not exists pgcrypto;
create extension if not exists citext;

-- Esquema privado para funciones de autorizacion. NO se expone via PostgREST:
-- Supabase solo publica los esquemas configurados (public, graphql_public).
create schema if not exists app;
comment on schema app is
  'Helpers internos de autorizacion. Nunca expuesto por la API. '
  'Las funciones son SECURITY DEFINER para poder consultar profiles sin '
  'disparar recursion infinita en las policies de la propia tabla.';

-- -----------------------------------------------------------------------------
-- Tipos
-- -----------------------------------------------------------------------------

-- moderator_outgoing = moderador saliente. A nivel permisos equivale a member;
-- existe para poder mostrarlo en la UI y guardar la historia del foro.
create type public.forum_role as enum (
  'member', 'moderator', 'moderator_elect', 'moderator_outgoing'
);

create type public.meeting_status as enum ('draft', 'scheduled', 'in_progress', 'closed');

-- ritual | eq (Deep Dive, emocional) | iq (que y como) | break.
-- EQ e IQ nunca se mezclan: son valores distintos en todo el sistema.
create type public.agenda_block_kind as enum ('ritual', 'eq', 'iq', 'break');

create type public.timer_state as enum ('idle', 'running', 'paused', 'done');

create type public.pillar as enum ('work', 'family', 'personal');

create type public.reflection_status as enum ('draft', 'final');

create type public.topic_kind as enum ('eq', 'iq');

-- q1 urgente+importante · q2 importante+no urgente · q3 prioridades ajenas · q4 diversion
create type public.quadrant as enum ('q1', 'q2', 'q3', 'q4');

create type public.parking_status as enum ('open', 'scheduled', 'done', 'archived');

create type public.poll_kind as enum ('meeting', 'retreat');

create type public.poll_status as enum ('open', 'closed');

-- Como se capturo el puntaje de cierre:
--   self = cada uno desde su celular, anonimo para el resto
--   room = dicho en voz alta en la sala y anotado por quien toma nota; ya es
--          publico, asi que se muestra con nombre
create type public.feedback_source as enum ('self', 'room');

-- -----------------------------------------------------------------------------
-- updated_at automatico
-- -----------------------------------------------------------------------------

create or replace function app.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
