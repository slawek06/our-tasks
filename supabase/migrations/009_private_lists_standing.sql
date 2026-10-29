-- Private shopping lists (only the owner sees the list and its items) and standing checklists
-- (never closed, e.g. "To talk about"). Run once: Supabase dashboard > SQL Editor > New query > paste > Run.
-- Safe to run more than once.
alter table public.lists add column if not exists private boolean not null default false;
alter table public.lists add column if not exists owner uuid default auth.uid() references auth.users on delete set null;
drop policy if exists "lists: signed-in users" on public.lists;
drop policy if exists "lists: shared or own private" on public.lists;
create policy "lists: shared or own private" on public.lists for all to authenticated
  using (not private or owner = auth.uid()) with check (not private or owner = auth.uid());
-- Items follow their list (items of the default Groceries list, which has no row, stay shared).
drop policy if exists "items: signed-in users" on public.items;
drop policy if exists "items: like their list" on public.items;
create policy "items: like their list" on public.items for all to authenticated
  using (not exists (select 1 from public.lists l where l.id = list_id and l.private and l.owner is distinct from auth.uid()))
  with check (not exists (select 1 from public.lists l where l.id = list_id and l.private and l.owner is distinct from auth.uid()));

alter table if exists public.checklists add column if not exists standing boolean not null default false;
alter table if exists public.checklist_items add column if not exists added_by text not null default '';
