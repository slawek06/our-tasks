-- Attachments on tasks (quotes, invoices): photos and PDFs, up to 10 per task, kept in a private Storage bucket.
-- A file's path is "<task id>/<random>.jpg" or ".pdf", so Storage never holds its real name. The name is on the row in
-- attachments, which follows its task like comments do. Each file is added once and never changed. The app can only read
-- and add: removing files is the server's job (notify, once a day), so an Undo can bring a file back.
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once. Needs 010.
-- Check afterwards with supabase/tests/privacy-check.sql.
create table if not exists public.attachments (
  id      text primary key,
  task_id text not null references public.tasks on delete cascade,
  name    text not null default '',  -- the name shown, e.g. "Quote kitchen.pdf"
  path    text not null,             -- where the file is in the task-files bucket
  size    bigint not null default 0, -- bytes
  author  text not null default '',  -- who added it: a or b
  at      bigint not null default 0
);
create index if not exists attachments_task_id_idx on public.attachments (task_id);
alter table public.attachments enable row level security;

drop policy if exists "attachments: not the other's private tasks" on public.attachments;
create policy "attachments: not the other's private tasks" on public.attachments for all to authenticated
  using (not private.others_private_task(task_id)) with check (not private.others_private_task(task_id));

grant select, insert, update, delete on public.attachments to authenticated;
grant all on public.attachments to service_role;
do $$ begin
  alter publication supabase_realtime add table public.attachments;
exception when duplicate_object then null; end $$;

-- Private: files are reachable only through the rules below, never by a plain web address.
-- 10 MB is the limit for a PDF; the app shrinks photos well below it before sending them.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('task-files', 'task-files', false, 10485760, array['image/jpeg', 'application/pdf'])
  on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- True when this person may see the task the file belongs to: the task exists and isn't the other person's private task.
-- It goes by the task, not the file, so a file follows when its task turns private. A file whose task is gone is
-- readable by nobody. Looks past the access rules like the 010 checks (security definer).
create or replace function private.task_file_allowed(path text) returns boolean
  language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.tasks t where t.id = split_part(path, '/', 1)
    and (not t.private or t.owner = auth.uid()));
$$;
revoke all on function private.task_file_allowed(text) from public, anon;
grant execute on function private.task_file_allowed(text) to authenticated;

drop policy if exists "task files: read like their task" on storage.objects;
create policy "task files: read like their task" on storage.objects for select to authenticated
  using (bucket_id = 'task-files' and private.task_file_allowed(name));
drop policy if exists "task files: add like their task" on storage.objects;
create policy "task files: add like their task" on storage.objects for insert to authenticated
  with check (bucket_id = 'task-files' and name ~ '^[^/]+/[^/]+\.(jpg|pdf)$' and private.task_file_allowed(name));
-- No update or delete rules on purpose: signed-in people can't change or remove files.

-- Files no attachment points at any more (task deleted, attachment removed), for notify to remove.
-- An hour's grace, so a file just added is safe while its row is being saved. Only the server may call this.
create or replace function public.stale_task_files() returns table (name text)
  language sql stable security definer set search_path = '' as $$
  select o.name from storage.objects o
    where o.bucket_id = 'task-files' and o.created_at < now() - interval '1 hour'
      and not exists (select 1 from public.attachments a where a.task_id = split_part(o.name, '/', 1) and a.path = o.name);
$$;
revoke all on function public.stale_task_files() from public, anon, authenticated;
grant execute on function public.stale_task_files() to service_role;
