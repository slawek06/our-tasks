# Our Tasks: architecture, technology and configuration

The reference for how the app is built and configured, detailed enough to rebuild it from nothing.
**Keep it current:** every change to the structure, database, server functions, hosting or settings updates this file
in the same commit.

Contents: 1 Overview · 2 Technology · 3 Code layout · 4 Front end · 5 Data model · 6 Access rules ·
7 Server functions · 8 Notifications and briefings · 9 Environments · 10 Configuration reference ·
11 Rebuild from scratch · 12 Workflow and releases · 13 Troubleshooting

---

## 1. Overview

A shared task tracker, shopping lists and checklists for two people, used on iPhone (home-screen app), Mac (Dock app)
and in the browser.

```
 iPhone / Mac (installed web app)
   index.html + sw.js  ── static files ──>  GitHub Pages  (main → /our-tasks/, dev → /our-tasks/dev/)
        │
        │ supabase-js (publishable key + the person's sign-in)
        ▼
 Supabase project ─ Postgres (tables + row level security) ─ Realtime (live changes)
                  ─ Storage (private buckets item-photos: photos of shopping items; task-files: photos and PDFs on tasks)
                  ─ Auth (email + password, email code/link; invited people only)
                  ─ Edge Functions:  claude  (Smart add, From text, Sort into areas)
                                     notify  (push, reminders, briefings, chat)  ◄── pg_cron every 5 min
                  ─ Secrets: ANTHROPIC_API_KEY (+ APP_URL in development)
        │
        ├─> Anthropic API (Claude) ── from the Edge Functions only
        └─> Apple / browser push services ── Web Push from the notify function
 Mail: Supabase Auth sends sign-in emails through Gmail SMTP.
```

There is no own server: GitHub hosts the files, Supabase holds data, sign-in and the two server functions.

## 2. Technology

| Part | Technology | Notes |
|---|---|---|
| App | One HTML file with plain JavaScript and CSS | No framework, no build step |
| Offline | Service worker (`sw.js`) + device copy in `localStorage` | Network first for app files; changes queue in an outbox |
| Installable | Web app manifest + icons | Add to Home Screen (iPhone), Add to Dock (Mac Safari) |
| Database | Supabase Postgres | Row level security on every table |
| Files | Supabase Storage, private buckets `item-photos` and `task-files` | Photos of shopping items and files on tasks, photos shrunk on the device; access rules follow the item or task. Both share the free plan's 1 GB |
| Live updates | Supabase Realtime (`postgres_changes`) | Access rules also filter what each person receives |
| Sign-in | Supabase Auth | Sign-ups off; email + password, or email code / link |
| Server code | Supabase Edge Functions (Deno, TypeScript) | `claude`, `notify` |
| AI | Claude API, model `claude-opus-5-5` | Effort `low`, server-side fallback beta; key only in Supabase |
| Push | Web Push, own implementation (RFC 8291 encryption, RFC 8292 VAPID) on WebCrypto | Keys created on first use, stored in `push_config` |
| Timer | `pg_cron` + `pg_net` | Calls `notify` with `action: tick` every 5 minutes |
| Hosting | GitHub Pages, published by GitHub Actions | Repository `slawek06/our-tasks` (public) |
| Mail | Gmail SMTP (app password) in Supabase Auth | Sign-in codes and invitations |
| Voice | Browser speech synthesis and recognition | Free, on the device |
| Fonts | Google Fonts: Bricolage Grotesque, Figtree, JetBrains Mono | |
| Library | `@supabase/supabase-js@2.45.4` from jsDelivr | Loaded at start |

## 3. Code layout

| Path | What it is |
|---|---|
| `index.html` | The whole app: markup, styles, logic |
| `sw.js` | Service worker: offline files, push display, notification taps. Bump `VERSION` when its file list changes |
| `manifest.webmanifest`, `manifest-dev.webmanifest` | App name, colours, icons (blue production, orange development) |
| `icons/`, `icons/dev/` | Icons, drawn by `scripts/make-icons.py` (pure Python) |
| `.github/workflows/pages.yml` | Publishes `main` to `/our-tasks/` and `dev` to `/our-tasks/dev/` (renames the dev copy and gives it the orange icon) |
| `supabase/schema.sql` | Base tables and access rules |
| `supabase/migrations/NNN_*.sql` | Later database changes, in order, each safe to run more than once |
| `supabase/tests/privacy-check.sql` | Paste into the SQL Editor: checks each person sees only what they should (PASS/FAIL), leaves nothing behind |
| `scripts/make-setup-sql.py <ref>` | Writes `supabase/setup-<ref>.sql`: schema + all migrations + permissions + timer for one project |
| `scripts/make-release-sql.py <first migration>` | Writes `supabase/release-<project name>.sql` for each project: a check that it's the right project (by the address in its timer job), the release's migrations, the privacy check |
| `supabase/functions/claude/index.ts` | Claude proxy for the app's AI features |
| `supabase/functions/notify/index.ts` | Push, reminders, briefings, briefing chat, timer |
| `docs/backlog.md` | Plans, decisions, designs |
| `docs/architecture.md` | This file |
| `CLAUDE.md` | Working rules for Claude sessions in this folder |
| `.claude/launch.json` | Local preview server (`python3 -m http.server 8765`) |
| `data/` (ignored by Git) | Personal exports and backups |

## 4. Front end (`index.html`)

**Environment.** `IS_DEV` is true when the address contains `/dev/`. `ENVIRONMENTS` holds each Supabase project's
URL and publishable key (public by design; the access rules protect the data).

**Store modes.** All data access goes through the `store` object:
- `supabase`: on https, or locally with `?supabase` in the address. Uses `sb`, the Supabase layer.
- `local`: opened as a file or on `http://localhost` without `?supabase`; data stays in that browser (preview mode).
- `remote`: the original claude.ai artifact version (no longer used, kept for compatibility).

**The `sb` layer.** One query per table at start, then Realtime keeps an in-memory copy current. A device copy
(`ot-cache-<user>`) lets the app open offline. Writes apply locally at once; if offline they wait in the outbox
(`ot-outbox-<user>`) and are sent in order later. Signing out deletes both from the device (after a warning if
unsent changes remain), also when signed out from another device; "Sign out" ends every session of that person. New rows get their id on the device, so links work before syncing.
Field names: the app uses camelCase, the database snake_case (`parentId` ↔ `parent_id`); `by` ↔ `author` and
`order` ↔ `sort_order` because BY and ORDER are reserved words.

**Feature checks.** Before a migration has run, the matching feature hides itself and says which file to run:
`pinsSupported` (002), `perListSupported` (003), notifications (004), Ideas (006), `areasSupported` (007),
checklists (008), `privateListsSupported` (009), seen markers (011: no marks until it runs), `followUpsSupported`
(012: a next step is a plain new task, without the link, and the form says which file to run), `dueTimeSupported`
(013, checks `remind_by`: no time field in the editor, which says which file to run; quick add leaves "10:30" in the title), `photosSupported`
(015: the item editor's Photo field says which file to run), `attachmentsSupported` (016: the task editor's Files field says which file to run). 010 only tightens access rules; the app works the same before it.

**Views.** Today · Tasks (Inbox + areas) · Upcoming · Lists (Shopping | Checklists) · Activity · Archive.
Panels: task editor, People (names, password, notifications, data), Briefing, From text, Ideas, Sort into areas,
shopping list editor.

**Seen markers.** Opening a task that the other person assigned to you, or seeing their comment, writes a row in
`seen_marks` the first time (`markOpened`, only while the app is visible, never for private tasks). The editor shows
the other person's marks: "Assigned by … · Wiola saw it 10:42" on tasks for them, and "Wiola saw it …" on your
comments. You never see your own marks.

**Mentions.** Typing `@` in a comment offers the other person's name (`#mention-pick`); `@Name` is shown in that
person's colour (`withMentions`). The push is decided by `notify` (see §7).

**Quick archive.** A closed task's row has an archive button where an open task has its My day button (`askArchive`): one tap with an Undo, and it asks first only if a subtask is still open.

**Done + next step.** Closing a task keeps its one tap; the toast offers "Next step" (`toast` takes a list of actions).
The editor has "Done + next step" on open tasks and "Add a next step" on closed ones (`askNextStep`: saves the editor as
usual, closing the task if open, then opens the form). The form (`openNextStep`, in the `#cascade` modal) saves the
outcome once as a comment (in the notes on a private task, which has no comments) and adds one new task per titled
row ("+ Another step" adds a row) under the same parent (the Inbox if that parent is archived; a closed parent reopens as
usual), each with `followUpOf` = the closed task, private if that task is private. The writes start together, so offline
they all wait in the outbox. The editor shows "Follow-up of: …" and "Follow-up: …" (`renderFollowUps`, tap to open), only for
tasks this person can read.

**Times and reminders.** A task with a date can have a time (`dueTime`, local "HH:MM"), when the thing happens: the editor's
Time field (a time with no date picks today; removing the date removes the time), or quick add ("Dentist tomorrow at 9:05",
"o 10:30"). Rows show "Today · 30 Oct · 10:30 · Remind 24h, 1h"; within a day, tasks with a time come first, earliest first
(`byTime`). With a time the editor offers reminders (`remindBefore`, `REMIND`): 24 hours, 1 hour, 15 minutes before, at the
time, any number of them; `remindBy` records who last set them (the date, time or reminders changed), and setting a time starts with 1 hour before (`DEFAULT_REMIND`, also for quick add), none ticked = no
reminder. Moving the date keeps the time and reminders; a repeating task's next copy keeps them too. The editor says who
gets them and which have already passed (`renderTimeHint`, matching `remindWho` in `notify`, see §8). The next-step form, From
text and the chat's suggestions set dates only.

**Every task has an owner.** A shared task belongs to one person or Both; there is no "No one" any more. A new task is Both, a
task under another task takes that task's person (`inheritedAssignee`; in the editor it follows "Belongs under" until you pick
someone), a next step takes the closed task's person, directly under an area or in the Inbox it's Both. Naming or picking someone
wins. The same goes for quick add, From text (the group inherits from where it goes), the chat's suggestions, checklist "make it a
task", repeats and an area turned back into a task. Empty on a shared task (an offline device, 014 not run yet) counts as Both
everywhere (`assigneeOf`) and is filled in on the next save without marking the task as newly assigned. Both shows as new for the
other person (`isNew`, because `assignedBy` is set) but sends no push (see §7).

**Photos of shopping items** (`photos`, decided 30 Oct 2026). One photo per item. The item editor's Add / Replace / Remove photo act at
once, like a comment; a hidden `<input type="file" accept="image/*">` makes the iPhone offer the camera and the library. `photos.shrink`
redraws it at most 1280 pixels on the longest side as JPEG (at most 900 KB, usually far less), which also drops the location the camera
stored in the file. The file goes up first (`<item id>/<random>.jpg`, never reused, sent with `cacheControl: "0"` so the browser's own
cache keeps no reusable copy), then `items.photo` points at it. Rows show a small picture (`photoButton`, in the shopping list and on the task's To buy rows); tapping it opens the large
view (`showPhoto`), tapping the rest of the row still ticks the item. Files are read with the person's sign-in (`download`), never
through a shareable link.
Offline: adding says it needs a connection, removing waits in the outbox like any change, and photos already seen still show: `photos.sync`
fetches every photo of a visible item ahead of time into Cache Storage (`ot-photos-<prod|dev|local>-<user>`). The service worker doesn't touch
it. A copy goes 15 seconds after its item stops pointing at it (`prune`; the wait outlasts an Undo), also when the item stopped being
readable, and the whole store goes on signing out, signing out from another device, or on reaching the sign-in screen. In preview mode the same store is the only place photos live.
A photo goes when its item goes (Finish shopping, Remove, deleting the list, Delete all data); the app never deletes files itself, `notify` removes the ones no item points at
(see §7), so an Undo brings the item back with its photo. An item bought for a task stays, with its photo. Deleting a private list also removes
its bought items, since without the list the access rules would show them to the other person. Backups hold the path, not the picture:
after a restore a photo that's gone shows as "no longer available".

**Files on tasks** (`taskFiles`, decided 30 Oct 2026). Photos and PDFs for quotes and invoices, up to 10 per task (`FILE_MAX`), in the task editor's Files field; saved tasks only, like
comments. Add and Remove act at once. Pictures of any kind the browser can open (JPEG, PNG, HEIC…) are redrawn on the device at most 2000 pixels on the longest side as JPEG (at most 1.5 MB, usually about 0.5 MB, larger than
item photos so small print stays readable), which also drops the camera's location; Chrome on a Mac can't open HEIC and says so. A PDF goes as it is, at most 10 MB. Anything else is refused with a message. `taskFiles` is `photos` with its own bucket, store and rules: the same fetching
and copies, with `<task id>/<random>.jpg|pdf` as the path, so Storage never holds the real name. The name, size, who and when are the row in `attachments`. Rows show "2 files"; search finds file names; the view (`showFile`) shows the picture or the PDF in a frame, with Share or save (on a phone: the share
sheet, which also shows every page of a PDF) or Download. Files are read with the person's sign-in, never through a shareable link.
Offline: adding says it needs a connection, removing waits in the outbox, files already seen still open. A copy reaches the phone once seen (a PDF when opened, a photo when its task is opened), in Cache Storage (`ot-files-<prod|dev|local>-<user>`). It goes 15 seconds after the file, its task or the right to
read it goes, or the task is archived (`prune`), and the whole store goes on signing out, signing out from another device, or on reaching the sign-in screen.
Closing a task changes nothing. An archived task keeps its files, to look at only, and restoring brings them back. Deleting a task removes its rows at once (and on the server with the task, `on delete cascade`); `notify` removes the files. Either person can remove a file on a shared task; Undo puts the row back. A next step or
a repeat's next copy starts without files. Adding pushes the other person (`notifyEvent("file", …)`, see §7). History names the file on shared tasks (`log` writes nothing for private tasks, so a private task's file is never named, also after the task is deleted). Backups hold the rows, not the files:
after a restore a file that's gone shows as "no longer available".

**People.** `config` row `people` = `{a, b, aUser, bUser}`: the two names and which account is which. The first person
is shown blue, the second green (`--p-a`, `--p-b`).

**Local settings per device** (`localStorage`): collapsed rows, sort order, chosen shopping list (`shopList`),
Lists part (`listsMode`).

## 5. Data model

All times are milliseconds since 1970 (`bigint`) unless noted; dates are `YYYY-MM-DD` text. Ids are text (UUIDs made
on the device).

| Table | Purpose | Main columns | Added by |
|---|---|---|---|
| `tasks` | Areas, projects and tasks in one tree | `title`, `kind` (`task`/`area`), `status` (`todo`/`doing`/`done`), `assignee` (`a`,`b`,`both` on shared tasks; `''` on private tasks and areas), `priority`, `due`, `due_time` (local "HH:MM", `''` = none), `remind_before` (minutes before, comma separated, from 1440, 60, 15, 0; `''` = no reminder), `remind_by` (who last set them, `a`/`b`), `repeat`, `parent_id`, `notes`, `sort_order`, `assigned_by`, `assigned_at`, `archived`, `archived_at`, `private`, `owner`, `follow_up_of` (id of the closed task it came out of, `''` = none) | schema, 007 (`kind`), 012 (`follow_up_of`), 013 (`due_time`, `remind_before`, `remind_by`) |
| `comments` | Comments on tasks | `task_id`, `text`, `author`, `by_user`, `at` | schema |
| `history` | Change log (Activity, task history) | `task_id`, `text`, `title`, `author`, `at` | schema |
| `lists` | Shopping lists (Groceries exists without a row) | `name`, `sort_order`, `private`, `owner` | schema, 009 |
| `items` | Shopping items | `list_id`, `name`, `qty`, `section`, `checked`, `bought`, `task_id`, `added_by`, `photo` (path of its file in `item-photos`, `''` = none), … | schema, 015 |
| `attachments` | Files on tasks | `task_id` (deleted with the task), `name` (shown), `path` (in `task-files`), `size` (bytes), `author`, `at` | 016 |
| `catalog` | Items bought before: suggestions and shop sections | `name`, `section`, `manual`, `count`, `list_counts` | schema, 003 |
| `config` | Shared settings (`people`) | `key`, `value` (json) | schema |
| `seen_marks` | "Wiola saw it 10:42": first time a person saw an assignment or comment | `id` (`<user>:<task>:<kind>:<ref>`), `user_id`, `task_id` (deleted with the task), `kind` (`assigned`/`comment`), `ref` (assigned_at or comment id), `at` | 011 |
| `user_state` | Per person: "new for you" and Activity/Shopping read markers, My day pins | `user_id`, `seen`, `activity_at`, `shopping_at`, `today` | schema, 002 |
| `push_subscriptions` | Devices that get push | `user_id`, `endpoint`, `p256dh`, `auth`, `device` | 004 |
| `notify_prefs` | Notification settings per person | `lang`, `tz`, `morning`, `evening`, `quiet_from/to`, `on_assigned/comment/closed`, `on_reminder`, `morning_sent`, `evening_sent` | 004, 005, 013 |
| `briefings` | Briefings and chat messages | `user_id`, `kind`, `role`, `text`, `actions` (json), `applied` | 004 |
| `push_config` | Server only: VAPID keys, timer password | `vapid`, `cron_secret` | 004 |
| `reminders_sent` | Server only: each reminder that went out, so it goes out once | `id` (`<user>:<task>:<date> <time>:<minutes before>`), `user_id`, `task_id` (deleted with the task), `at` | 013 |
| `ideas` | Feedback inbox | `text`, `kind` (`idea`/`problem`), `author`, `by_user`, `at`, `moved` | 006 |
| `checklists` | Templates, lists, standing lists | `title`, `template`, `template_id`, `standing`, `closed`, `closed_at`, `private`, `owner` | 008, 009 |
| `checklist_items` | Checklist items and headings | `checklist_id`, `text`, `heading`, `done`, `done_by`, `done_at`, `added_by`, `sort_order` | 008, 009 |

**Concepts.**
- An **area** is a `tasks` row with `kind = 'area'` at the top level; it has no status, dates or assignee.
  A **project** is any task with tasks under it. Top-level tasks without an area show in the **Inbox**.
- Closing a task closes its open subtasks (two-step confirmation); archiving moves the whole branch.
- A **checklist template** is never ticked; **Start** copies its items into a new list; closing a list archives it
  and offers to add new items to the template. **Standing** lists are never closed.
- A **private** task, area, checklist or shopping list is visible only to its `owner`.

## 6. Access rules (row level security)

- Every table allows only signed-in users (`authenticated`); anonymous visitors get nothing.
- `tasks`, `checklists`, `lists`: `not private or owner = auth.uid()`.
- `checklist_items` follow their checklist; `items` follow their list (items of a private list are hidden from the other person).
- `comments` and `history` follow their task: those of a private task only for its owner (history without a task is shared).
- Rules that must look at the other person's private rows (`items`, `comments`, `history`) use the security definer
  functions `private.others_private_task(id)` and `private.others_private_list(id)` (010). A plain subquery would
  itself be filtered by the access rules, never see the private row, and let everything through (009's mistake).
  The `private` schema isn't exposed by the API.
- Check the rules any time with `supabase/tests/privacy-check.sql`.
- **Photos** (015): bucket `item-photos` is private (1 MB limit, JPEG only). The rules on `storage.objects` go by the item in the file's path,
  through the security definer function `private.item_photo_allowed(path)`: the item must exist and not be on the other person's private list.
  So a photo follows its item when it moves or its list turns private, and a file whose item is gone is readable by nobody. Signed-in people can
  only read and add; there are no update or delete rules. `items.photo` gives no access by itself: pointing an item at someone else's file shows nothing.
- `public.stale_item_photos()` (015) lists the files to remove; only the service role may call it.
- **Files on tasks** (016): bucket `task-files` is private (10 MB limit, JPEG and PDF only). `attachments` rows follow their task like comments (`private.others_private_task`), and go with it. The rules on `storage.objects` go by the task in the file's path,
  through the security definer function `private.task_file_allowed(path)`: the task must exist and not be the other person's private task. So a file follows its task when it turns private, and a file whose task is gone is readable by nobody. Signed-in people can
  only read and add; there are no update or delete rules. A row's `path` gives no access by itself. `public.stale_task_files()` lists the files to remove; only the service role may call it.
- `follow_up_of` (012) is a plain column on `tasks` and adds no rule: a task's link to the other person's private task
  shows them nothing, because they can't read that row.
- `seen_marks` (011): everyone writes only their own rows (the id must match what they mark); both read them, except
  marks on the other person's private task.
- `user_state`, `push_subscriptions`, `notify_prefs`, `briefings`: own rows only.
- `push_config`, `reminders_sent`: no rules at all, so only the server functions (service role) can read them.
  `reminders_sent` also has its permissions revoked for `anon` and `authenticated`, and the privacy check tests it.
- New projects created with "Automatically expose new tables" off need explicit `grant`s; `make-setup-sql.py` adds them.
- Realtime publication `supabase_realtime` includes the shared tables.

## 7. Server functions (Supabase Edge Functions)

Both check the caller's sign-in themselves (`auth.getUser(token)`). The dashboard setting **Verify JWT** must be
**off** for `notify` (the timer has no user token); `claude` works either way. They use the built-in `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.

**`claude`.** Body `{prompt}` → Claude (`claude-opus-5-5`, effort low) → `{text}`. Used by Smart add (shopping),
From text, Sort into areas. Errors: `not_signed_in` 401, `not_configured`, `rate_limited` 429.

**`notify`.** Body `{action, …}`:
- `vapid`: public push key (keys are created and stored in `push_config` on first use)
- `test`: push to the caller's devices
- `event` (`assigned`, `comment`, `closed`, `file`): instant push to the other person, respecting their switches and quiet hours.
  `assigned` pushes only when the task is theirs by name, never for Both. This is the one place that rule lives: the app calls
  `notifyEvent("assigned", …)` on every assignment and `notify` decides
  A comment with `@<their name>` is a mention: it pushes even with their Comments switch off, titled
  "Sławek mentioned you in …" (one push, never two); quiet hours still apply. `file` ("Sławek added a file to …", the file's name below) follows the Comments switch; nothing for private tasks
- `brief_now`, `chat`: briefing and conversation, written by Claude from a snapshot of the caller's open tasks,
  shopping, standing-list topics and recent activity (never the other person's private items); proposed changes come
  back as `actions` that the app applies only after confirmation
- Errors answer `server_error` without details; the reason goes to the function's logs.
- `tick`: called by the timer with header `x-cron-secret` (from `push_config`); sends due reminders, then due
  morning/evening briefings. Once a day, in the first run after 03:00 UTC, also `removeStaleFiles`: removes the files `stale_item_photos()` lists,
  those no item points at (item or list deleted, photo replaced or removed), and those `stale_task_files()` lists, those no attachment points at (task deleted, file removed), all more than an hour old. Each does nothing before its migration (015, 016) and a failure only goes to the logs.
- `APP_URL` (secret, optional): address opened from notifications; defaults to production

## 8. Notifications and briefings

- The app subscribes the device with the VAPID public key and stores the subscription in `push_subscriptions`.
- On iPhone, push works only in the home-screen app (iOS 16.4+).
- Briefings: morning (default 07:30) and evening (20:00) per person, in English or Polish, friendly and short,
  written to sound natural when read aloud. They go out at the time the person chose, even inside their quiet hours.
- Quiet hours: per person, set under People (`quiet_from`, `quiet_to`, default 22:00 to 07:00), on that person's own clock
  (`tz`). They may cross midnight; the same time twice, or a cleared time, means no quiet hours (`inQuiet` in `notify`).
  Instant pushes in quiet hours are not sent, then or later.
- Reminders (decided 30 Oct 2026): pushes the chosen time before a task's date and time (24 hours, 1 hour, 15 minutes, at the
  time; several allowed), on the person's own clock (`tz`), at most about 5 minutes late. Titled "In 1 hour · 10:30". Goes to the
  owner of a private task; on a shared task to the assignee, and to both when it's set to Both (or still empty).
  Quiet hours: only your own reminder can wake you. A moment in quiet hours waits until they end if it's 24 hours before (the
  event is still far off) or the other person set it (`remind_by`), and is dropped if the event is over by then; a shorter one you
  set yourself, or on your private task, rings anyway, so your 6:15 train still gets its reminder. Each person's Task reminders
  switch (`on_reminder`, under People) turns theirs off altogether. Closed, archived and area rows never send.
  Each goes out once: writing its `reminders_sent` row decides that, so overlapping timers can't double-send; a new date or
  time is a new id, so it's recalculated. If no device takes it the row is removed and the next tick tries again. A moment
  more than 10 minutes past (`REMINDER_LATE_MIN`, two timer runs: time set too late, timer down) is skipped. Quiet hours are read
  when the timer runs, so a reminder that's waiting follows any change to them; if the new end has already passed by more than
  those 10 minutes, it isn't sent.
- Timer: `pg_cron` job `our-tasks-notify`, `*/5 * * * *` (changed from every 15 minutes by 013, which alters only the
  schedule, so it's safe in either project), `net.http_post` to the project's `/functions/v1/notify`. Briefings don't go out
  twice: `morning_sent` / `evening_sent` are set to today's date before each is written.

## 9. Environments

| | Production | Development |
|---|---|---|
| App address | https://slawek06.github.io/our-tasks/ | https://slawek06.github.io/our-tasks/dev/ |
| Look | Blue icon, "Our Tasks" | Orange icon, "Our Tasks DEV", DEV badge |
| Git branch | `main` | `dev` |
| Supabase project | `jwhuaaxrymdqwanwthvg` (our-tasks-prod, Frankfurt) | `sjtdrnvezorxxdoitszz` (London, test data) |
| Auth Site URL | `https://slawek06.github.io/our-tasks/` | `https://slawek06.github.io/our-tasks/dev/` |
| Function secrets | `ANTHROPIC_API_KEY` | `ANTHROPIC_API_KEY`, `APP_URL` = dev address |

**Which migrations each environment has** (update when you run one):

| Migration | Production | Development |
|---|---|---|
| schema + 002–007 | ✅ | ✅ |
| 008 checklists | ✅ (run again 29 Oct 2026) | ✅ |
| 009 private lists, standing lists | ✅ 29 Oct 2026 | ✅ |
| 010 private comments and history, private list items fix | ✅ 29 Oct 2026, privacy check all PASS | ✅ privacy check all PASS (26 Oct 2026) |
| 011 seen markers | ⬜ next release | ✅ privacy check all PASS (30 Oct 2026) |
| 012 follow-ups (Done + next step) | ⬜ next release | ✅ 30 Oct 2026 |
| 013 reminders (due time, reminder choices, sent records, 5-minute timer) | ✅ run early by mistake 30 Oct 2026, harmless (rerun at the release) | ✅ privacy check all PASS (30 Oct 2026) |
| 014 every task has an owner (open shared tasks with nobody assigned become Both) | ⬜ next release | ✅ privacy check all PASS (30 Oct 2026) |
| 015 photos of shopping items (`items.photo`, bucket `item-photos`, its rules, `stale_item_photos`) | ⬜ next release | ✅ privacy check all PASS (30 Oct 2026) |
| 016 files on tasks (`attachments`, bucket `task-files`, its rules, `stale_task_files`) | ⬜ next release | ✅ privacy check all PASS (30 Oct 2026) |

## 10. Configuration reference

Secrets are never stored in this repository or sent in chats. They live only where listed.

| Setting | Where | Value |
|---|---|---|
| Publishable keys | `index.html` → `ENVIRONMENTS` | Public; one per project |
| `ANTHROPIC_API_KEY` | Supabase → Edge Functions → Secrets (both projects) | From console.anthropic.com |
| `APP_URL` | Supabase secrets (development only) | `https://slawek06.github.io/our-tasks/dev/` |
| Database password, `sb_secret` / service role key | Supabase only | Never needed by the app |
| Sign-ups | Auth → Sign In / Providers | **Allow new users to sign up: off**; Email provider on |
| Site URL / Redirect URLs | Auth → URL Configuration | The environment's app address (see §9) |
| SMTP | Auth → Emails → SMTP Settings | Host `smtp.gmail.com`, port `465`, user and sender = the Gmail address, password = Gmail app password, sender name `Our Tasks` |
| Email rate limit | Auth → Rate Limits | 30 emails per hour |
| Magic Link template | Auth → Emails → Templates | `<h2>Sign in to Our Tasks</h2><p>Your code: <strong>{{ .Token }}</strong></p><p>Or open this link: <a href="{{ .ConfirmationURL }}">Sign in</a></p>` |
| Users | Auth → Users → Invite user | The two people |
| Function settings | Edge Functions → each function | Name `claude` / `notify` (set the name before the first deploy); Verify JWT off |
| Photo and file storage | Created by migrations 015 and 016 / setup file | Buckets `item-photos` and `task-files`, private; show under Storage in the dashboard. Nothing to set by hand |
| Timer | Created by migration 004 / setup file; every 5 minutes since 013 | Job `our-tasks-notify` |
| GitHub Pages | Repo → Settings → Pages | Source: **GitHub Actions** |
| Deployment branches | Repo → Settings → Environments → github-pages | `main` and `dev` allowed |
| Git identity | Repo-local git config | Author `slawek06`, email `89165628+slawek06@users.noreply.github.com` (no real name or email on GitHub) |

## 11. Rebuild from scratch

1. **GitHub:** create the repository, push the code, set Pages source to GitHub Actions and allow `main` and `dev`
   under Environments → github-pages.
2. **Supabase:** create a project (region close to you). Note its URL and publishable key.
3. **Database:** run `python3 scripts/make-setup-sql.py <project-ref>`, paste `supabase/setup-<ref>.sql` into the SQL
   Editor, Run.
4. **App config:** put the URL and publishable key into `ENVIRONMENTS` in `index.html` (prod or dev).
5. **Auth:** sign-ups off, Site URL and Redirect URL, Gmail SMTP, rate limit, Magic Link template (§10).
6. **Functions:** create `claude` and `notify` (name first), paste the code, Verify JWT off, deploy.
   Add secret `ANTHROPIC_API_KEY` (and `APP_URL` for a development project).
7. **People:** invite both people. Each signs in, taps "I'm …", sets a password under People, adds the app to the
   home screen / Dock and turns on notifications.
8. **Data (optional):** People → Your data → import a backup file from `data/`.
9. **Check:** functions answer `not_signed_in` (401) without sign-in; the timer gets `forbidden` (403) without its secret.

## 12. Workflow and releases

- Build on `dev`; it publishes to the orange app automatically. Try it there.
- Database changes: a new numbered migration, safe to run more than once; run in development first.
- Collect several items, then **release**: run `python3 scripts/make-release-sql.py <first migration of the release>`, try `supabase/release-our-tasks.sql` in development, merge `dev` into `main`,
  run `supabase/release-our-tasks-prod.sql` in production (it ends with the privacy check), deploy changed functions to production, update §9.
  The file stops with "STOP: this is the wrong Supabase project" in the other project, before changing anything.
- Record decisions and status in `docs/backlog.md`; structure and settings here.
- Commit messages explain why; no secrets, no personal data in the repository.

## 13. Troubleshooting

| Symptom | Likely cause |
|---|---|
| "… needs the database update: run …" | That environment hasn't run the named migration |
| Sign-in email without a code | Custom SMTP off: Supabase sends its default mail and ignores the template |
| Login fails in the Dock / home-screen app | Separate sign-in from Safari; Safari may autofill the other environment's password (same web address) |
| Dev app not updating after a push | `dev` not allowed under Environments → github-pages |
| Saves refused | Check the toast's server reason; Supabase status page for incidents |
| No notifications on iPhone | Only in the home-screen app; turn on under People in that app |
| Item photo stays on the camera sign | Offline and not yet on this device, or the file is gone; online it's fetched by itself |
| A file won't open or shows the camera sign | Offline and not yet on this device, or the file is gone; online it's fetched by itself |
| Function returns 404 / `not_configured` | Function missing, misnamed, or `ANTHROPIC_API_KEY` not set |
