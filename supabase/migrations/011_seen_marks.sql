-- Seen markers: "Wiola saw it 10:42" on tasks assigned to the other person and on comments.
-- One row per thing a person has seen, written the first time they open it: an assignment (ref = the task's
-- assigned_at) or a comment (ref = the comment's id). Each person writes only their own rows; both can read them,
-- except on the other person's private tasks.
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once. Needs 010.
-- Check afterwards with supabase/tests/privacy-check.sql.
create table if not exists public.seen_marks (
  id       text primary key,                     -- '<user id>:<task id>:<kind>:<ref>'
  user_id  uuid not null default auth.uid() references auth.users on delete cascade,
  task_id  text not null references public.tasks on delete cascade,
  kind     text not null check (kind in ('assigned', 'comment')),
  ref      text not null,
  at       bigint not null default 0              -- when it was first seen
);
create index if not exists seen_marks_task_id_idx on public.seen_marks (task_id);
alter table public.seen_marks enable row level security;

drop policy if exists "seen_marks: read unless the other's private task" on public.seen_marks;
create policy "seen_marks: read unless the other's private task" on public.seen_marks for select to authenticated
  using (user_id = auth.uid() or not private.others_private_task(task_id));
-- Writing: only your own marks, with an id that matches what they mark.
drop policy if exists "seen_marks: write own" on public.seen_marks;
create policy "seen_marks: write own" on public.seen_marks for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and id = user_id::text || ':' || task_id || ':' || kind || ':' || ref
              and not private.others_private_task(task_id));

grant select, insert, update, delete on public.seen_marks to authenticated;
grant all on public.seen_marks to service_role;
do $$ begin
  alter publication supabase_realtime add table public.seen_marks;
exception when duplicate_object then null; end $$;
