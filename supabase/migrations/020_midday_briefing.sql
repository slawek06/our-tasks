-- A third briefing, at midday: per person, off until they set a time. Each of the three can be on or off separately.
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once. Needs 004.
alter table public.notify_prefs add column if not exists midday text not null default '';      -- '' = no midday briefing
alter table public.notify_prefs add column if not exists midday_sent text not null default ''; -- last local date one went out (set by the server)
