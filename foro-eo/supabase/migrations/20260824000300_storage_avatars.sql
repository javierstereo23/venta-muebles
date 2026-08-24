-- =============================================================================
-- 0003 · Bucket privado de fotos de perfil.
-- Convencion de ruta: avatars/<user_id>/<archivo>. Bucket NO publico: las fotos
-- se sirven con signed URLs de vida corta, nunca con un link permanente.
-- =============================================================================

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

-- Devuelve el dueño segun la primera carpeta de la ruta, o null si no es un uuid.
create or replace function app.storage_owner(p_name text)
returns uuid language plpgsql immutable as $$
begin
  return (storage.foldername(p_name))[1]::uuid;
exception when others then
  return null;
end;
$$;

create policy avatars_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and app.is_forum_member(app.profile_forum(app.storage_owner(name)))
  );

create policy avatars_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and app.storage_owner(name) = auth.uid());

create policy avatars_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and app.storage_owner(name) = auth.uid())
  with check (bucket_id = 'avatars' and app.storage_owner(name) = auth.uid());

create policy avatars_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and app.storage_owner(name) = auth.uid());
