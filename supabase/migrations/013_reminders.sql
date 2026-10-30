-- Reminders at a time of day: a task can have a time as well as a date, and a push arrives at that time.
-- due_time is local "HH:MM" ('' = no time, no reminder). reminders_sent records each reminder that went out, one row per
-- person and date + time, so it goes out once only, and a new date or time counts as a new reminder. Server only: no access
-- rules and no permissions for the app, like push_config.
-- The timer checks every 5 minutes instead of 15 (it stays pointed at this project; briefings are marked as sent per day,
-- so they don't go out twice).
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once.
-- Check afterwards with supabase/tests/privacy-check.sql.
alter table public.tasks add column if not exists due_time text not null default '';

create table if not exists public.reminders_sent (
  id       text primary key,                     -- '<user id>:<task id>:<YYYY-MM-DD HH:MM>'
  user_id  uuid not null references auth.users on delete cascade,
  task_id  text not null references public.tasks on delete cascade,
  at       bigint not null default 0             -- when it was sent
);
create index if not exists reminders_sent_task_id_idx on public.reminders_sent (task_id);
alter table public.reminders_sent enable row level security;
revoke all on public.reminders_sent from anon, authenticated;
grant all on public.reminders_sent to service_role;

select cron.alter_job(job_id := jobid, schedule := '*/5 * * * *') from cron.job where jobname = 'our-tasks-notify';
