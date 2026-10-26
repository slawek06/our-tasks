-- Comments and history of a private task are readable only by its owner, and items of a private shopping list
-- really are hidden from the other person (the 009 rule looked the list up through its own access rule, so the
-- other person's private list was invisible to the check and its items showed).
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once.
-- Check afterwards with supabase/tests/privacy-check.sql.

-- The checks look past the access rules (security definer), so they can see the other person's private rows.
-- They live in a schema the app's API doesn't expose, so they can't be called from outside.
create schema if not exists private;
grant usage on schema private to authenticated;

-- True when the task is someone else's private task.
create or replace function private.others_private_task(tid text) returns boolean
  language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.tasks t where t.id = tid and t.private and t.owner is distinct from auth.uid());
$$;
-- True when the shopping list is someone else's private list.
create or replace function private.others_private_list(lid text) returns boolean
  language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.lists l where l.id = lid and l.private and l.owner is distinct from auth.uid());
$$;
revoke all on function private.others_private_task(text), private.others_private_list(text) from public, anon;
grant execute on function private.others_private_task(text), private.others_private_list(text) to authenticated;

drop policy if exists "comments: signed-in users" on public.comments;
drop policy if exists "comments: not the other's private tasks" on public.comments;
create policy "comments: not the other's private tasks" on public.comments for all to authenticated
  using (not private.others_private_task(task_id)) with check (not private.others_private_task(task_id));

-- History without a task (task_id '') stays shared.
drop policy if exists "history: signed-in users" on public.history;
drop policy if exists "history: not the other's private tasks" on public.history;
create policy "history: not the other's private tasks" on public.history for all to authenticated
  using (not private.others_private_task(task_id)) with check (not private.others_private_task(task_id));

drop policy if exists "items: like their list" on public.items;
create policy "items: like their list" on public.items for all to authenticated
  using (not private.others_private_list(list_id)) with check (not private.others_private_list(list_id));

-- Older history named the item added to a private list from a shared task; keep the note, drop the name.
update public.history set text = 'added an item to a private list'
  where text like 'added “%” to a private list';
