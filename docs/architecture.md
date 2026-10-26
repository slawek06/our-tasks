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
                  ─ Auth (email + password, email code/link; invited people only)
                  ─ Edge Functions:  claude  (Smart add, From text, Sort into areas)
                                     notify  (push, briefings, chat)  ◄── pg_cron every 15 min
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
| Live updates | Supabase Realtime (`postgres_changes`) | Access rules also filter what each person receives |
| Sign-in | Supabase Auth | Sign-ups off; email + password, or email code / link |
| Server code | Supabase Edge Functions (Deno, TypeScript) | `claude`, `notify` |
| AI | Claude API, model `claude-opus-5-5` | Effort `low`, server-side fallback beta; key only in Supabase |
| Push | Web Push, own implementation (RFC 8291 encryption, RFC 8292 VAPID) on WebCrypto | Keys created on first use, stored in `push_config` |
| Timer | `pg_cron` + `pg_net` | Calls `notify` with `action: tick` every 15 minutes |
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
| `supabase/functions/claude/index.ts` | Claude proxy for the app's AI features |
| `supabase/functions/notify/index.ts` | Push, briefings, briefing chat, timer |
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
(`ot-outbox-<user>`) and are sent in order later. New rows get their id on the device, so links work before syncing.
Field names: the app uses camelCase, the database snake_case (`parentId` ↔ `parent_id`); `by` ↔ `author` and
`order` ↔ `sort_order` because BY and ORDER are reserved words.

**Feature checks.** Before a migration has run, the matching feature hides itself and says which file to run:
`pinsSupported` (002), `perListSupported` (003), notifications (004), Ideas (006), `areasSupported` (007),
checklists (008), `privateListsSupported` (009). 010 only tightens access rules; the app works the same before it.

**Views.** Today · Tasks (Inbox + areas) · Upcoming · Lists (Shopping | Checklists) · Activity · Archive.
Panels: task editor, People (names, password, notifications, data), Briefing, From text, Ideas, Sort into areas,
shopping list editor.

**People.** `config` row `people` = `{a, b, aUser, bUser}`: the two names and which account is which. The first person
is shown blue, the second green (`--p-a`, `--p-b`).

**Local settings per device** (`localStorage`): collapsed rows, sort order, chosen shopping list (`shopList`),
Lists part (`listsMode`).

## 5. Data model

All times are milliseconds since 1970 (`bigint`) unless noted; dates are `YYYY-MM-DD` text. Ids are text (UUIDs made
on the device).

| Table | Purpose | Main columns | Added by |
|---|---|---|---|
| `tasks` | Areas, projects and tasks in one tree | `title`, `kind` (`task`/`area`), `status` (`todo`/`doing`/`done`), `assignee` (`''`,`a`,`b`,`both`), `priority`, `due`, `repeat`, `parent_id`, `notes`, `sort_order`, `assigned_by`, `assigned_at`, `archived`, `archived_at`, `private`, `owner` | schema, 007 (`kind`) |
| `comments` | Comments on tasks | `task_id`, `text`, `author`, `by_user`, `at` | schema |
| `history` | Change log (Activity, task history) | `task_id`, `text`, `title`, `author`, `at` | schema |
| `lists` | Shopping lists (Groceries exists without a row) | `name`, `sort_order`, `private`, `owner` | schema, 009 |
| `items` | Shopping items | `list_id`, `name`, `qty`, `section`, `checked`, `bought`, `task_id`, `added_by`, … | schema |
| `catalog` | Items bought before: suggestions and shop sections | `name`, `section`, `manual`, `count`, `list_counts` | schema, 003 |
| `config` | Shared settings (`people`) | `key`, `value` (json) | schema |
| `user_state` | Per person: seen markers, My day pins | `user_id`, `seen`, `activity_at`, `shopping_at`, `today` | schema, 002 |
| `push_subscriptions` | Devices that get push | `user_id`, `endpoint`, `p256dh`, `auth`, `device` | 004 |
| `notify_prefs` | Notification settings per person | `lang`, `tz`, `morning`, `evening`, `quiet_from/to`, `on_assigned/comment/closed`, `morning_sent`, `evening_sent` | 004, 005 |
| `briefings` | Briefings and chat messages | `user_id`, `kind`, `role`, `text`, `actions` (json), `applied` | 004 |
| `push_config` | Server only: VAPID keys, timer password | `vapid`, `cron_secret` | 004 |
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
- `user_state`, `push_subscriptions`, `notify_prefs`, `briefings`: own rows only.
- `push_config`: no rules at all, so only the server functions (service role) can read it.
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
- `event` (`assigned`, `comment`, `closed`): instant push to the other person, respecting their switches and quiet hours
- `brief_now`, `chat`: briefing and conversation, written by Claude from a snapshot of the caller's open tasks,
  shopping, standing-list topics and recent activity (never the other person's private items); proposed changes come
  back as `actions` that the app applies only after confirmation
- `tick`: called by the timer with header `x-cron-secret` (from `push_config`); sends due morning/evening briefings
- `APP_URL` (secret, optional): address opened from notifications; defaults to production

## 8. Notifications and briefings

- The app subscribes the device with the VAPID public key and stores the subscription in `push_subscriptions`.
- On iPhone, push works only in the home-screen app (iOS 16.4+).
- Briefings: morning (default 07:30) and evening (20:00) per person, in English or Polish, friendly and short,
  written to sound natural when read aloud. Quiet hours 22:00–07:00 for instant notifications.
- Timer: `pg_cron` job `our-tasks-notify`, `*/15 * * * *`, `net.http_post` to the project's `/functions/v1/notify`.

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
| 008 checklists | ✅ (run early, harmless) | run before testing checklists |
| 009 private lists, standing lists | ⬜ next release | run before testing |
| 010 private comments and history, private list items fix | ⬜ next release | run, then the privacy check |

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
| Timer | Created by migration 004 / setup file | Job `our-tasks-notify` |
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
- Collect several items, then **release**: merge `dev` into `main`, run the release's migrations in production,
  deploy changed functions to production, update §9.
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
| Function returns 404 / `not_configured` | Function missing, misnamed, or `ANTHROPIC_API_KEY` not set |
