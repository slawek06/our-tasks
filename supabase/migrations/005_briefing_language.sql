-- Briefing language per person: 'en' (English) or 'pl' (Polish).
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once.
alter table public.notify_prefs add column if not exists lang text not null default 'en';
