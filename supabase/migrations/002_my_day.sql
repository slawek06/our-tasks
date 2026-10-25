-- My day: each person's tasks pinned for today, as {"<task id>": "YYYY-MM-DD"}.
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run.
-- Safe to run more than once. (Already included in schema.sql for new projects.)
alter table public.user_state add column if not exists today jsonb not null default '{}'::jsonb;
