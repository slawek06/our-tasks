-- Our Tasks: notifications, briefings and the briefing chat.
-- Run once: Supabase dashboard > SQL Editor > New query > paste this whole file > Run.
-- Safe to run more than once.

-- Devices that receive push notifications (one row per phone / Mac app). Each person sees only their own.
create table if not exists public.push_subscriptions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  endpoint    text not null unique,
  p256dh      text not null,
  auth        text not null,
  device      text not null default '',
  created_at  timestamptz not null default now()
);
alter table public.push_subscriptions enable row level security;
drop policy if exists "push_subscriptions: own rows" on public.push_subscriptions;
create policy "push_subscriptions: own rows" on public.push_subscriptions
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Each person's notification settings. Times are local "HH:MM" in their time zone.
create table if not exists public.notify_prefs (
  user_id      uuid primary key default auth.uid() references auth.users on delete cascade,
  lang         text not null default 'en',             -- briefing language: en | pl (also added by 005)
  tz           text not null default 'Europe/Warsaw',
  morning      text not null default '07:30',   -- '' = no morning briefing
  evening      text not null default '20:00',   -- '' = no evening check
  quiet_from   text not null default '22:00',   -- no instant notifications between quiet_from and quiet_to
  quiet_to     text not null default '07:00',
  on_assigned  boolean not null default true,
  on_comment   boolean not null default true,
  on_closed    boolean not null default true,
  morning_sent text not null default '',        -- last local date a briefing went out (set by the server)
  evening_sent text not null default ''
);
alter table public.notify_prefs enable row level security;
drop policy if exists "notify_prefs: own row" on public.notify_prefs;
create policy "notify_prefs: own row" on public.notify_prefs
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Briefings and the conversation about them. Each person sees only their own.
create table if not exists public.briefings (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  kind        text not null default 'chat',     -- morning | evening | chat
  role        text not null default 'user',     -- user | assistant
  text        text not null,
  actions     jsonb not null default '[]'::jsonb, -- changes Claude proposes; applied only when you confirm
  applied     boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists briefings_user_time on public.briefings (user_id, created_at desc);
alter table public.briefings enable row level security;
drop policy if exists "briefings: own rows" on public.briefings;
create policy "briefings: own rows" on public.briefings
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Server-only settings: the push signing keys and the timer's password. No policies = no access from the app;
-- only the notify function (with the service role) can read it.
create table if not exists public.push_config (
  id           int primary key default 1 check (id = 1),
  vapid        jsonb,
  cron_secret  text not null default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')
);
alter table public.push_config enable row level security;
insert into public.push_config (id) values (1) on conflict (id) do nothing;

-- Timer: every 15 minutes, ask the notify function to send briefings that are due.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
select cron.unschedule('our-tasks-notify') where exists (select 1 from cron.job where jobname = 'our-tasks-notify');
select cron.schedule('our-tasks-notify', '*/15 * * * *', $job$
  select net.http_post(
    url     := 'https://sjtdrnvezorxxdoitszz.supabase.co/functions/v1/notify',
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'x-cron-secret', (select cron_secret from public.push_config where id = 1)),
    body    := '{"action":"tick"}'::jsonb
  );
$job$);
