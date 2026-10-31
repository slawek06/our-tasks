-- Remembering an item's photo: adding "coffee" again brings back its photo. Only for shared lists: a photo on a private
-- list is never remembered. The suggestion (catalog row, one per item name, shared by both) points at the same file, so
-- no copy is made; a new photo replaces the remembered one and removing a photo forgets it.
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once. Needs 015.
-- Check afterwards with supabase/tests/privacy-check.sql.
alter table public.catalog add column if not exists photo text not null default '';

-- A file may now outlive the item it was added for, and several items may point at it. Readable when something
-- still uses it (the item it was added for, an item pointing at it, a remembered photo), and never while it's on the
-- other person's private list, whatever else points at it. Adding a file still needs a real item: see 015's rule.
create or replace function private.item_photo_allowed(path text) returns boolean
  language sql stable security definer set search_path = '' as $$
  select not exists (select 1 from public.items i join public.lists l on l.id = i.list_id
      where (i.id = split_part(path, '/', 1) or i.photo = path) and l.private and l.owner is distinct from auth.uid())
    and (exists (select 1 from public.items i where i.id = split_part(path, '/', 1) or i.photo = path)
      or exists (select 1 from public.catalog c where c.photo = path));
$$;
revoke all on function private.item_photo_allowed(text) from public, anon;
grant execute on function private.item_photo_allowed(text) to authenticated;

-- Adding goes by the item alone: pointing a suggestion at a path must not make a new file possible there.
drop policy if exists "item photos: add like their item" on storage.objects;
create policy "item photos: add like their item" on storage.objects for insert to authenticated
  with check (bucket_id = 'item-photos' and name ~ '^[^/]+/[^/]+\.jpg$' and private.item_photo_allowed(name)
              and exists (select 1 from public.items i where i.id = split_part(name, '/', 1)));

-- Files nothing points at any more, for notify to remove. A remembered photo stays.
create or replace function public.stale_item_photos() returns table (name text)
  language sql stable security definer set search_path = '' as $$
  select o.name from storage.objects o
    where o.bucket_id = 'item-photos' and o.created_at < now() - interval '1 hour'
      and not exists (select 1 from public.items i where i.photo = o.name)
      and not exists (select 1 from public.catalog c where c.photo = o.name);
$$;
revoke all on function public.stale_item_photos() from public, anon, authenticated;
grant execute on function public.stale_item_photos() to service_role;
