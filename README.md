# Our Tasks

A shared task tracker and shopping list for two people.

Live: https://slawek06.github.io/our-tasks/ (sign-in required; only invited people)

## Environments

| | Production | Development |
|---|---|---|
| App | https://slawek06.github.io/our-tasks/ (blue icon) | https://slawek06.github.io/our-tasks/dev/ (orange icon, "DEV") |
| Git branch | `main` | `dev` |
| Supabase project | `jwhuaaxrymdqwanwthvg` (our-tasks-prod, Frankfurt) | `sjtdrnvezorxxdoitszz` (London, test data) |
| Sign-in Site URL | `/our-tasks/` | `/our-tasks/dev/` |
| Secrets | `ANTHROPIC_API_KEY` | `ANTHROPIC_API_KEY`, `APP_URL` = dev address |

Workflow: build on `dev` (published to /dev/ by the GitHub Action), try it on the orange app, then merge
into `main`. Database changes: add a migration, run it in development first, then in production.
Edge Functions are the same code in both projects; deploy to development first.
A new project gets its full database from `python3 scripts/make-setup-sql.py <project-ref>`.

## Features

- Areas (big themes like a home or Finances) holding projects and tasks; an Inbox and "Sort into areas" for the rest
- Tasks nested to any depth, with status (not started / in progress / done), assignee, due date, priority, notes and repeats
- Closing a task closes its open subtasks after a two-step confirmation; closed tasks take no new subtasks
- Archive with restore, including unfinished tasks
- Private tasks, readable only by their owner (enforced by the database)
- Upcoming view (overdue, today, next 7 days, later) and an Activity feed of recent changes
- Comments, per-task history, "new for you" markers, drag-to-reorder
- Shopping lists: quick add with quantities, suggestions, automatic shop sections, basket, shopping mode, several lists
- Items to buy linked to tasks
- Checklists: reusable templates (e.g. leaving one home for the other); start a fresh list, tick together, close to archive
- Smart add and "create tasks from text" using Claude
- Ideas: a shared inbox for app feedback, copied into the chat with Claude to plan changes
- Works offline: changes wait on the device and sync when back online
- Installable on iPhone (Add to Home Screen) and Mac (Add to Dock)

## How it's built

- `index.html`: the whole app (plain HTML, CSS and JavaScript, no build step), hosted on GitHub Pages.
  All data access goes through the `store` object; on the hosted site it uses Supabase.
  Opened as a plain file, it runs in preview mode with data kept in that browser only.
- `sw.js`: service worker that keeps the app files on the device for offline use.
- `manifest.webmanifest`, `icons/`: app name and icons; `scripts/make-icons.py` redraws the icons.
- `supabase/schema.sql`: database tables and access rules (row level security).
- `supabase/functions/claude/index.ts`: Edge Function that calls Claude for Smart add and "from text".
  The Anthropic API key is a Supabase secret (`ANTHROPIC_API_KEY`), never in this repository.
- `supabase/functions/notify/index.ts`: Edge Function for push notifications (Web Push with its own
  RFC 8291/8292 code), the morning/evening briefings written by Claude, and the briefing chat whose
  proposed changes the app applies only after you confirm. A pg_cron job calls it every 15 minutes.
- `supabase/migrations/`: database updates to run once in the SQL Editor (002 My day, 003 per-list
  frequent items, 004 notifications and briefings, 005 briefing language, 006 ideas for the app, 007 areas, 008 checklists).

## Setup notes

- Supabase: sign-ups are off; people are invited under Authentication > Users. They sign in with
  email + password (set under People in the app) or with an emailed link/code.
- People > Your data: import an export file, download a backup, or delete all data for a clean start.

## Rules

- Never commit secrets (API keys, passwords, service credentials). They go in `.env` (ignored),
  Supabase secrets, or GitHub Secrets.
- Personal data exports live in `data/`, which Git ignores.
- Small commits with clear messages.
