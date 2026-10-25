-- Areas: top-level themes (a home, Insurance, Finances) that hold projects and tasks but are never "done".
-- They live in the tasks table with kind = 'area', so sharing and private areas work exactly like tasks.
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once.
alter table public.tasks add column if not exists kind text not null default 'task';
do $$ begin
  alter table public.tasks add constraint tasks_kind_check check (kind in ('task', 'area'));
exception when duplicate_object then null; end $$;
