-- Ideas and problems for the app itself, collected by both of you and later moved to docs/backlog.md.
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once.
create table if not exists public.ideas (
  id        text primary key default gen_random_uuid()::text,
  text      text not null,
  kind      text not null default 'idea' check (kind in ('idea', 'problem')),
  author    text not null default '',
  by_user   uuid default auth.uid(),
  at        bigint not null default 0,
  moved     boolean not null default false,  -- taken into the backlog
  moved_at  bigint
);
alter table public.ideas enable row level security;
drop policy if exists "ideas: signed-in users" on public.ideas;
create policy "ideas: signed-in users" on public.ideas for all to authenticated using (true) with check (true);
grant select, insert, update, delete on public.ideas to authenticated;
grant all on public.ideas to service_role;
do $$ begin
  alter publication supabase_realtime add table public.ideas;
exception when duplicate_object then null; end $$;
