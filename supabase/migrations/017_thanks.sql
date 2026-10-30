-- Thanks: a one-tap thank-you (a heart, a flower, the sun, a beer...) for a task the other person closed.
-- One row per person per task; choosing another picture replaces it, tapping the same one takes it back.
-- Each person writes only their own rows and never on a private task; both can read them, except on the other
-- person's private tasks. The pictures offered are chosen in the app, so adding one needs no database change.
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once. Needs 010.
-- Check afterwards with supabase/tests/privacy-check.sql.
create table if not exists public.thanks (
  id       text primary key,                     -- '<user id>:<task id>'
  user_id  uuid not null default auth.uid() references auth.users on delete cascade,
  task_id  text not null references public.tasks on delete cascade,
  emoji    text not null check (char_length(emoji) between 1 and 16),
  at       bigint not null default 0              -- when it was sent
);
create index if not exists thanks_task_id_idx on public.thanks (task_id);
alter table public.thanks enable row level security;

drop policy if exists "thanks: read unless the other's private task" on public.thanks;
create policy "thanks: read unless the other's private task" on public.thanks for select to authenticated
  using (user_id = auth.uid() or not private.others_private_task(task_id));
-- Writing: only your own, with an id that matches, and only on a shared task.
drop policy if exists "thanks: write own" on public.thanks;
create policy "thanks: write own" on public.thanks for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and id = user_id::text || ':' || task_id
              and exists (select 1 from public.tasks t where t.id = task_id and not t.private));

grant select, insert, update, delete on public.thanks to authenticated;
grant all on public.thanks to service_role;
do $$ begin
  alter publication supabase_realtime add table public.thanks;
exception when duplicate_object then null; end $$;
