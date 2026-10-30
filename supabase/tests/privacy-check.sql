-- Privacy check: can each person see only what they should?
-- Run any time: Supabase dashboard > SQL Editor > New query > paste this whole file > Run.
-- It adds a few test rows, looks at them as each of the two people, then undoes everything, so nothing is left.
-- The result is a table with PASS or FAIL per line. Needs migrations 009, 010, 011, 013 and 015.
--
-- "A" is the person who owns the private test task and list (the first account), "B" is the other person.
-- Works with a single account, so also in a development project with only one user.

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

-- Tries to write a seen marker in someone else's name (as the given person, signed as "as_uid").
create or replace function pg_temp.can_mark_as(uid uuid, as_uid uuid, tid text) returns boolean language plpgsql as $$
declare ok boolean;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    insert into public.seen_marks (id, user_id, task_id, kind, ref) values (as_uid || ':' || tid || ':comment:x', as_uid, tid, 'comment', 'x');
    ok := true;
  exception when others then ok := false;
  end;
  execute 'reset role';
  return ok;
end $$;

-- Tries to read or add reminder records, which only the server may touch (as the given person).
create or replace function pg_temp.can_touch_reminders(uid uuid, tid text) returns boolean language plpgsql as $$
declare ok boolean := false; n int;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    select count(*) into n from public.reminders_sent;
    ok := n > 0;
  exception when others then null;
  end;
  begin
    insert into public.reminders_sent (id, user_id, task_id) values ('privacy-check-r2-' || uid, uid, tid);
    ok := true;
  exception when others then null;
  end;
  execute 'reset role';
  return ok;
end $$;

-- Tries to add a photo file for an item, as the given person (the same insert Storage makes for the app).
create or replace function pg_temp.can_add_photo(uid uuid, item text, file text) returns boolean language plpgsql as $$
declare ok boolean;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    insert into storage.objects (bucket_id, name) values ('item-photos', item || '/' || file);
    ok := true;
  exception when others then ok := false;
  end;
  execute 'reset role';
  return ok;
end $$;

-- Is this photo file visible to the given person? No person: an anonymous visitor.
create or replace function pg_temp.sees_photo(uid uuid, path text) returns boolean language plpgsql as $$
declare n int;
begin
  perform set_config('request.jwt.claims', case when uid is null then '{"role":"anon"}' else json_build_object('sub', uid, 'role', 'authenticated')::text end, true);
  execute case when uid is null then 'set local role anon' else 'set local role authenticated' end;
  select count(*) into n from storage.objects where bucket_id = 'item-photos' and name = path;
  execute 'reset role';
  return n > 0;
end $$;

-- Tries to change or remove a photo file, which only the server may do (as the given person).
create or replace function pg_temp.can_change_photo(uid uuid, path text) returns boolean language plpgsql as $$
declare ok boolean := false; n int;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    update storage.objects set name = path || '.changed' where bucket_id = 'item-photos' and name = path;
    get diagnostics n = row_count;
    ok := n > 0;
  exception when others then null;
  end;
  begin
    delete from storage.objects where bucket_id = 'item-photos' and name = path;
    get diagnostics n = row_count;
    ok := ok or n > 0;
  exception when others then null;
  end;
  execute 'reset role';
  return ok;
end $$;

-- Tries to ask for the list of photo files to remove, which only the server may do (as the given person).
create or replace function pg_temp.can_list_stale_photos(uid uuid) returns boolean language plpgsql as $$
declare ok boolean;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    perform * from public.stale_item_photos();
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
    ["B", "items",    "privacy-check-i2", true,  "item on Groceries"],
    ["B", "seen_marks", "privacy-check-m1", true,  "A''s seen marker on a shared task"],
    ["B", "seen_marks", "privacy-check-m2", false, "A''s seen marker on A''s private task"],
    ["A", "seen_marks", "privacy-check-m2", true,  "own seen marker on own private task"]
  ]';
  c jsonb; got boolean; i int := 0; ph jsonb := '[]';
begin
  -- A owns rows, so must be a real account; B only looks, so any made-up id stands in for "the other person".
  select id into ua from auth.users order by created_at limit 1;
  if ua is null then raise exception 'The privacy check needs a user in Authentication > Users.'; end if;
  ub := gen_random_uuid();

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
    insert into public.seen_marks (id, user_id, task_id, kind, ref) values
      ('privacy-check-m1', ua, 'privacy-check-t1', 'comment', 'privacy-check-c1'),
      ('privacy-check-m2', ua, 'privacy-check-t2', 'comment', 'privacy-check-c2');
    insert into public.reminders_sent (id, user_id, task_id) values ('privacy-check-r1', ua, 'privacy-check-t2');

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
    got := pg_temp.can_mark_as(ub, ua, 'privacy-check-t1');
    res := res || jsonb_build_object('n', i + 2, 'who', 'B', 'what', 'can write a seen marker in A''s name',
      'expected', 'no', 'actual', case when got then 'yes' else 'no' end, 'result', case when got then 'FAIL' else 'PASS' end);
    got := pg_temp.can_touch_reminders(ua, 'privacy-check-t2');
    res := res || jsonb_build_object('n', i + 3, 'who', 'A', 'what', 'can read or add reminder records (server only)',
      'expected', 'no', 'actual', case when got then 'yes' else 'no' end, 'result', case when got then 'FAIL' else 'PASS' end);
    got := pg_temp.can_touch_reminders(ub, 'privacy-check-t1');
    res := res || jsonb_build_object('n', i + 4, 'who', 'B', 'what', 'can read or add reminder records (server only)',
      'expected', 'no', 'actual', case when got then 'yes' else 'no' end, 'result', case when got then 'FAIL' else 'PASS' end);

    -- Photos of shopping items, tried in this order: each line is who, what happened, what it should be.
    i := i + 4;
    ph := ph || jsonb_build_array(jsonb_build_array('A', 'can add a photo to an item on own private list', pg_temp.can_add_photo(ua, 'privacy-check-i1', 'a.jpg'), true));
    ph := ph || jsonb_build_array(jsonb_build_array('A', 'can add a photo to an item on Groceries', pg_temp.can_add_photo(ua, 'privacy-check-i2', 'a.jpg'), true));
    ph := ph || jsonb_build_array(jsonb_build_array('B', 'can add a photo to an item on A''s private list', pg_temp.can_add_photo(ub, 'privacy-check-i1', 'b.jpg'), false));
    ph := ph || jsonb_build_array(jsonb_build_array('B', 'can add a photo for an item that doesn''t exist', pg_temp.can_add_photo(ub, 'privacy-check-none', 'b.jpg'), false));
    ph := ph || jsonb_build_array(jsonb_build_array('A', 'sees the photo of an item on own private list', pg_temp.sees_photo(ua, 'privacy-check-i1/a.jpg'), true));
    ph := ph || jsonb_build_array(jsonb_build_array('B', 'sees the photo of an item on A''s private list', pg_temp.sees_photo(ub, 'privacy-check-i1/a.jpg'), false));
    ph := ph || jsonb_build_array(jsonb_build_array('B', 'sees the photo of an item on Groceries', pg_temp.sees_photo(ub, 'privacy-check-i2/a.jpg'), true));
    ph := ph || jsonb_build_array(jsonb_build_array('Nobody', 'anonymous visitor sees the photo of an item on Groceries', pg_temp.sees_photo(null, 'privacy-check-i2/a.jpg'), false));
    ph := ph || jsonb_build_array(jsonb_build_array('B', 'can change or remove the photo of an item on A''s private list', pg_temp.can_change_photo(ub, 'privacy-check-i1/a.jpg'), false));
    ph := ph || jsonb_build_array(jsonb_build_array('B', 'can change or remove the photo of an item on Groceries', pg_temp.can_change_photo(ub, 'privacy-check-i2/a.jpg'), false));
    ph := ph || jsonb_build_array(jsonb_build_array('B', 'can ask for the list of photo files to remove (server only)', pg_temp.can_list_stale_photos(ub), false));
    ph := ph || jsonb_build_array(jsonb_build_array('Everyone', 'photo storage is open to the public', coalesce((select public from storage.buckets where id = 'item-photos'), true), false));
    for c in select * from jsonb_array_elements(ph) loop
      i := i + 1;
      got := (c->>2)::boolean;
      res := res || jsonb_build_object('n', i, 'who', c->>0, 'what', c->>1,
        'expected', case when (c->>3)::boolean then 'yes' else 'no' end, 'actual', case when got then 'yes' else 'no' end,
        'result', case when got = (c->>3)::boolean then 'PASS' else 'FAIL' end);
    end loop;
    -- A photo follows its item: moved onto A's private list, the Groceries photo disappears for B.
    update public.items set list_id = 'privacy-check-l1' where id = 'privacy-check-i2';
    got := pg_temp.sees_photo(ub, 'privacy-check-i2/a.jpg');
    res := res || jsonb_build_object('n', i + 1, 'who', 'B', 'what', 'sees the photo after its item moved to A''s private list',
      'expected', 'no', 'actual', case when got then 'yes' else 'no' end, 'result', case when got then 'FAIL' else 'PASS' end);
    -- A file whose item is gone is readable by nobody, not even by the person who added it.
    delete from public.items where id = 'privacy-check-i1';
    got := pg_temp.sees_photo(ua, 'privacy-check-i1/a.jpg');
    res := res || jsonb_build_object('n', i + 2, 'who', 'A', 'what', 'sees a photo whose item was deleted',
      'expected', 'no', 'actual', case when got then 'yes' else 'no' end, 'result', case when got then 'FAIL' else 'PASS' end);

    raise exception 'privacy_check_undo'; -- undoes every test row above
  exception when raise_exception then
    if sqlerrm <> 'privacy_check_undo' then raise; end if;
  end;
  insert into privacy_check select * from jsonb_to_recordset(res)
    as x(n int, who text, what text, expected text, actual text, result text);
end $$;

select * from privacy_check order by n;
