-- Task icons: a small emoji next to a task's title, picked by Claude Haiku on the 5-minute timer.
-- Empty (null) means none picked yet; '' means Claude's answer wasn't an emoji, so the timer leaves it alone. Private
-- tasks are never sent to Claude, so they have none. Access is the task's own, so nothing else changes.
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once.
alter table public.tasks add column if not exists icon text;
