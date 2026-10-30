-- Done + next step: a task can be the follow-up of another one, the closed task it came out of.
-- follow_up_of holds that task's id ('' = none). It follows the row's own access rules, and the app shows the link only
-- when it can read the other task, so a follow-up never reveals the other person's private task.
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once.
alter table public.tasks add column if not exists follow_up_of text not null default '';
