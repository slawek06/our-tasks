-- Frequent items per shopping list: how often each item was added to each list, as {"<list id>": count}.
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run.
-- Safe to run more than once. (Already included in schema.sql for new projects.)
alter table public.catalog add column if not exists list_counts jsonb not null default '{}'::jsonb;
