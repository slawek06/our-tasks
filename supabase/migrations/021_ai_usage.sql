-- Claude usage: what each call to Claude cost, so the app can show this month's total against the spending limit.
-- Only the server functions write and read the rows. The app sees totals by feature through ai_usage_summary(),
-- never single requests, and nothing says which person made a call. Amounts are estimates from the tokens Claude
-- reports and the published prices; the bill at console.anthropic.com is exact.
-- The limit and the 80% warning live in config, key 'ai': {"limit": 5, "warned": {"<user id>": "YYYY-MM"}}.
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once.
create table if not exists public.ai_usage (
  id            text primary key default gen_random_uuid()::text,
  at            timestamptz not null default now(),
  feature       text not null,             -- briefing | chat | icons | smart_add | from_text | sort_areas
  model         text not null,
  input_tokens  integer not null default 0,
  output_tokens integer not null default 0,
  cost          numeric(12, 6) not null default 0   -- US dollars
);
create index if not exists ai_usage_at_idx on public.ai_usage (at);
alter table public.ai_usage enable row level security; -- no rules on purpose: signed-in people can't read or write rows
grant all on public.ai_usage to service_role;

-- This calendar month and the last one (UTC, like Anthropic's monthly limit), summed by feature.
create or replace function public.ai_usage_summary() returns table (month text, feature text, cost numeric, since timestamptz)
  language sql stable security definer set search_path = '' as $$
  select to_char(date_trunc('month', u.at at time zone 'UTC'), 'YYYY-MM'), u.feature, sum(u.cost),
         (select min(at) from public.ai_usage)
    from public.ai_usage u
    where u.at >= (date_trunc('month', now() at time zone 'UTC') - interval '1 month') at time zone 'UTC'
    group by 1, 2;
$$;
revoke all on function public.ai_usage_summary() from public, anon;
grant execute on function public.ai_usage_summary() to authenticated;
