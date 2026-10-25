-- Our Tasks: database structure and access rules for Supabase.
-- Run once: Supabase dashboard > SQL Editor > New query > paste this file > Run.
--
-- Access model
--   * Sign-ups are switched off in the dashboard; the only users are the two people invited there.
--   * Every table allows signed-in users only (row level security). The public "publishable" key
--     in the app alone cannot read or write anything.
--   * Private tasks are visible only to their owner, enforced by the database, not by the app.
--
-- Column names are snake_case; the app maps them to its camelCase fields
-- (parent_id <-> parentId). "author" is stored for the app's "by", and "sort_order" for "order",
-- because BY and ORDER are reserved words in SQL.
-- Times are milliseconds since 1970 (bigint) and due dates are 'YYYY-MM-DD' text, as in the app.

-- ---------- tables ----------

create table public.tasks (
  id           text primary key default gen_random_uuid()::text,
  title        text not null,
  status       text not null default 'todo'   check (status in ('todo', 'doing', 'done')),
  assignee     text not null default ''       check (assignee in ('', 'a', 'b', 'both')),
  priority     text not null default 'normal' check (priority in ('low', 'normal', 'high')),
  due          text not null default '',
  repeat       text not null default '',
  parent_id    text not null default '',
  notes        text not null default '',
  sort_order   double precision not null default 0,
  created_at   bigint not null default 0,
  assigned_by  text not null default '',
  assigned_at  bigint not null default 0,
  archived     boolean not null default false,
  archived_at  bigint,
  private      boolean not null default false,
  owner        uuid default auth.uid() references auth.users on delete set null
);

create table public.comments (
  id       text primary key default gen_random_uuid()::text,
  task_id  text not null,
  text     text not null,
  author   text not null default '',
  by_user  uuid default auth.uid(),
  at       bigint not null default 0
);

create table public.history (
  id       text primary key default gen_random_uuid()::text,
  task_id  text not null,
  text     text not null,
  title    text not null default '',
  author   text not null default '',
  at       bigint not null default 0
);

create table public.lists (
  id          text primary key default gen_random_uuid()::text,
  name        text not null,
  sort_order  double precision not null default 0
);

create table public.items (
  id             text primary key default gen_random_uuid()::text,
  list_id        text not null default 'groceries',
  name           text not null,
  qty            text not null default '',
  section        text not null default 'Other',
  checked        boolean not null default false,
  checked_at     bigint,
  bought         boolean not null default false,
  bought_at      bigint,
  task_id        text not null default '',
  added_by       text not null default '',
  added_by_user  uuid default auth.uid(),
  added_at       bigint not null default 0
);

-- What you have bought before: powers suggestions and remembered shop sections.
create table public.catalog (
  id       text primary key,
  name     text not null,
  section  text not null default 'Other',
  manual   boolean not null default false,
  count    integer not null default 0,
  last_at  bigint not null default 0
);

-- Small shared settings, e.g. key 'people' = {"a": "...", "b": "...", "aUser": "<uuid>", "bUser": "<uuid>"}.
create table public.config (
  key    text primary key,
  value  jsonb not null default '{}'::jsonb
);

-- Per-person state ("what I've already seen"), private to each person.
create table public.user_state (
  user_id      uuid primary key default auth.uid() references auth.users on delete cascade,
  seen         jsonb not null default '{}'::jsonb,
  activity_at  bigint not null default 0,
  shopping_at  bigint not null default 0,
  today        jsonb not null default '{}'::jsonb  -- My day pins: {"<task id>": "YYYY-MM-DD"}
);

create index on public.tasks (parent_id);
create index on public.comments (task_id);
create index on public.history (task_id);
create index on public.history (at desc);
create index on public.items (task_id);

-- ---------- access rules ----------

alter table public.tasks      enable row level security;
alter table public.comments   enable row level security;
alter table public.history    enable row level security;
alter table public.lists      enable row level security;
alter table public.items      enable row level security;
alter table public.catalog    enable row level security;
alter table public.config     enable row level security;
alter table public.user_state enable row level security;

-- Shared tasks for both of you; private tasks only for their owner.
create policy "tasks: shared or own private" on public.tasks
  for all to authenticated
  using (not private or owner = auth.uid())
  with check (not private or owner = auth.uid());

create policy "comments: signed-in users" on public.comments  for all to authenticated using (true) with check (true);
create policy "history: signed-in users"  on public.history   for all to authenticated using (true) with check (true);
create policy "lists: signed-in users"    on public.lists     for all to authenticated using (true) with check (true);
create policy "items: signed-in users"    on public.items     for all to authenticated using (true) with check (true);
create policy "catalog: signed-in users"  on public.catalog   for all to authenticated using (true) with check (true);
create policy "config: signed-in users"   on public.config    for all to authenticated using (true) with check (true);

create policy "user_state: own row only" on public.user_state
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------- live updates ----------
-- Changes are pushed to the open app instantly; the access rules above still apply to what each person receives.

alter publication supabase_realtime add table
  public.tasks, public.comments, public.history, public.lists,
  public.items, public.catalog, public.config, public.user_state;
