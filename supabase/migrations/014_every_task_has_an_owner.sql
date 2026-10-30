-- Every task has an owner: existing open shared tasks with nobody assigned become Both, once.
-- Private tasks and areas have no assignee and stay as they are. Closed and archived rows stay as they are too: they
-- are history, and if one comes back the app treats its empty assignee as Both and fills it in on the next save.
-- assigned_by and assigned_at stay empty, so nothing shows as new for anyone. No push: pushes are sent only by the app
-- calling notify, never by a database change. Who gets a reminder doesn't change either (empty and both both mean both of you).
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run. Safe to run more than once.
update public.tasks set assignee = 'both'
  where assignee = '' and kind = 'task' and not private and not archived and status <> 'done';
