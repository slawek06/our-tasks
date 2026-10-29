-- Checklists: reusable templates and the lists started from them (e.g. "Leaving Warsaw · Fri 31 Oct").
-- Shared or private like tasks. Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once.
create table if not exists public.checklists (
  id           text primary key default gen_random_uuid()::text,
  title        text not null,
  template     boolean not null default false,   -- a reusable version; never ticked
  template_id  text not null default '',         -- the template a list was started from
  closed       boolean not null default false,
  closed_at    bigint,
  sort_order   double precision not null default 0,
  created_at   bigint not null default 0,
  private      boolean not null default false,
  owner        uuid default auth.uid() references auth.users on delete set null
);
create table if not exists public.checklist_items (
  id            text primary key default gen_random_uuid()::text,
  checklist_id  text not null,
  text          text not null,
  heading       boolean not null default false,  -- "Before we go:", "Bring:"
  done          boolean not null default false,
  done_by       text not null default '',
  done_at       bigint,
  sort_order    double precision not null default 0
);
create index if not exists checklist_items_checklist_id_idx on public.checklist_items (checklist_id);
alter table public.checklists enable row level security;
alter table public.checklist_items enable row level security;
drop policy if exists "checklists: shared or own private" on public.checklists;
create policy "checklists: shared or own private" on public.checklists for all to authenticated
  using (not private or owner = auth.uid()) with check (not private or owner = auth.uid());
-- Items follow their list: readable and writable when the list is.
drop policy if exists "checklist_items: like their list" on public.checklist_items;
create policy "checklist_items: like their list" on public.checklist_items for all to authenticated
  using (exists (select 1 from public.checklists c where c.id = checklist_id and (not c.private or c.owner = auth.uid())))
  with check (exists (select 1 from public.checklists c where c.id = checklist_id and (not c.private or c.owner = auth.uid())));
grant select, insert, update, delete on public.checklists, public.checklist_items to authenticated;
grant all on public.checklists, public.checklist_items to service_role;
do $$ begin
  alter publication supabase_realtime add table public.checklists, public.checklist_items;
exception when duplicate_object then null; end $$;
