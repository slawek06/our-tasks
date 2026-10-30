-- Photo of a shopping item ("this exact brand"): one photo per item, kept in a private Storage bucket.
-- A file's path is "<item id>/<random>.jpg" and the item's photo column holds that path. Each file is added once and
-- never changed, so a new photo is a new file. The app can only read and add: removing files is the server's job
-- (notify, once a day), so an Undo can bring back an item with its photo.
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once. Needs 010.
-- Check afterwards with supabase/tests/privacy-check.sql.
alter table public.items add column if not exists photo text not null default '';

-- Private: files are reachable only through the rules below, never by a plain web address.
-- The limit is a backstop; the app shrinks photos well below it before sending them.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('item-photos', 'item-photos', false, 1048576, array['image/jpeg'])
  on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- True when this person may see the item the file belongs to: the item exists and isn't on the other person's private
-- list. It goes by the item, not the file, so a photo follows when an item moves or its list turns private. A file
-- whose item is gone is readable by nobody. Looks past the access rules like the 010 checks (security definer).
create or replace function private.item_photo_allowed(path text) returns boolean
  language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.items i where i.id = split_part(path, '/', 1)
    and not exists (select 1 from public.lists l where l.id = i.list_id and l.private and l.owner is distinct from auth.uid()));
$$;
revoke all on function private.item_photo_allowed(text) from public, anon;
grant execute on function private.item_photo_allowed(text) to authenticated;

drop policy if exists "item photos: read like their item" on storage.objects;
create policy "item photos: read like their item" on storage.objects for select to authenticated
  using (bucket_id = 'item-photos' and private.item_photo_allowed(name));
drop policy if exists "item photos: add like their item" on storage.objects;
create policy "item photos: add like their item" on storage.objects for insert to authenticated
  with check (bucket_id = 'item-photos' and name ~ '^[^/]+/[^/]+\.jpg$' and private.item_photo_allowed(name));
-- No update or delete rules on purpose: signed-in people can't change or remove files.

-- Files no item points at any more (item or list deleted, photo replaced or removed), for notify to remove.
-- An hour's grace, so a file just added is safe while its item is being saved. Only the server may call this.
create or replace function public.stale_item_photos() returns table (name text)
  language sql stable security definer set search_path = '' as $$
  select o.name from storage.objects o
    where o.bucket_id = 'item-photos' and o.created_at < now() - interval '1 hour'
      and not exists (select 1 from public.items i where i.id = split_part(o.name, '/', 1) and i.photo = o.name);
$$;
revoke all on function public.stale_item_photos() from public, anon, authenticated;
grant execute on function public.stale_item_photos() to service_role;
