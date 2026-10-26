-- Privacy check: can each person see only what they should?
-- Run any time: Supabase dashboard > SQL Editor > New query > paste this whole file > Run.
-- It adds a few test rows, looks at them as each of the two people, then undoes everything, so nothing is left.
-- The result is a table with PASS or FAIL per line. Needs migrations 009 and 010.
--
-- "A" is the person who owns the private test task and list, "B" is the other person.

create temp table if not exists privacy_check (n int, who text, what text, expected text, actual text, result text);
truncate privacy_check;

-- Counts rows with this id in this table, as the given person.
create or replace function pg_temp.sees(uid uuid, tbl text, rid text) returns boolean language plpgsql as $$
declare n int;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute format('select count(*) from public.%I where id = $1', tbl) into n using rid;
  execute 'reset role';
  return n > 0;
end $$;

-- Tries to add a comment to a task, as the given person.
create or replace function pg_temp.can_comment(uid uuid, tid text) returns boolean language plpgsql as $$
declare ok boolean;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    insert into public.comments (id, task_id, text) values ('privacy-check-c3-' || uid, tid, 'test');
    ok := true;
  exception when others then ok := false;
  end;
  execute 'reset role';
  return ok;
end $$;

do $$
declare
  ua uuid; ub uuid; res jsonb := '[]';
  checks jsonb := '[
    ["B", "comments", "privacy-check-c1", true,  "comment on a shared task"],
    ["B", "comments", "privacy-check-c2", false, "comment on A''s private task"],
    ["A", "comments", "privacy-check-c2", true,  "comment on own private task"],
    ["B", "history",  "privacy-check-h1", true,  "history of a shared task"],
    ["B", "history",  "privacy-check-h2", false, "history of A''s private task"],
    ["A", "history",  "privacy-check-h2", true,  "history of own private task"],
    ["B", "history",  "privacy-check-h3", true,  "history without a task"],
    ["B", "tasks",    "privacy-check-t2", false, "A''s private task"],
    ["B", "lists",    "privacy-check-l1", false, "A''s private shopping list"],
    ["B", "items",    "privacy-check-i1", false, "item on A''s private list"],
    ["A", "items",    "privacy-check-i1", true,  "item on own private list"],
    ["B", "items",    "privacy-check-i2", true,  "item on Groceries"]
  ]';
  c jsonb; got boolean; i int := 0;
begin
  select (value->>'aUser')::uuid, (value->>'bUser')::uuid into ua, ub from public.config where key = 'people';
  if ua is null or ub is null or ua = ub then
    select id into ua from auth.users order by created_at limit 1;
    select id into ub from auth.users where id <> ua order by created_at limit 1;
  end if;
  if ua is null or ub is null then raise exception 'The privacy check needs two users in Authentication > Users.'; end if;

  begin
    insert into public.tasks (id, title, private, owner) values
      ('privacy-check-t1', 'Privacy check: shared', false, ua), ('privacy-check-t2', 'Privacy check: private', true, ua);
    insert into public.comments (id, task_id, text) values
      ('privacy-check-c1', 'privacy-check-t1', 'test'), ('privacy-check-c2', 'privacy-check-t2', 'test');
    insert into public.history (id, task_id, text) values
      ('privacy-check-h1', 'privacy-check-t1', 'test'), ('privacy-check-h2', 'privacy-check-t2', 'test'), ('privacy-check-h3', '', 'test');
    insert into public.lists (id, name, private, owner) values ('privacy-check-l1', 'Privacy check', true, ua);
    insert into public.items (id, list_id, name) values
      ('privacy-check-i1', 'privacy-check-l1', 'test'), ('privacy-check-i2', 'groceries', 'test');

    for c in select * from jsonb_array_elements(checks) loop
      i := i + 1;
      got := pg_temp.sees(case c->>0 when 'A' then ua else ub end, c->>1, c->>2);
      res := res || jsonb_build_object('n', i, 'who', c->>0, 'what', 'sees ' || (c->>4),
        'expected', case when (c->>3)::boolean then 'yes' else 'no' end, 'actual', case when got then 'yes' else 'no' end,
        'result', case when got = (c->>3)::boolean then 'PASS' else 'FAIL' end);
    end loop;
    got := pg_temp.can_comment(ub, 'privacy-check-t2');
    res := res || jsonb_build_object('n', i + 1, 'who', 'B', 'what', 'can comment on A''s private task',
      'expected', 'no', 'actual', case when got then 'yes' else 'no' end, 'result', case when got then 'FAIL' else 'PASS' end);

    raise exception 'privacy_check_undo'; -- undoes every test row above
  exception when raise_exception then
    if sqlerrm <> 'privacy_check_undo' then raise; end if;
  end;
  insert into privacy_check select * from jsonb_to_recordset(res)
    as x(n int, who text, what text, expected text, actual text, result text);
end $$;

select * from privacy_check order by n;
