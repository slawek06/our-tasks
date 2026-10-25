# Our Tasks

A shared task tracker and shopping list for two people.

Live: https://slawek06.github.io/our-tasks/ (sign-in required; only invited people)

## Features

- Tasks nested to any depth, with status (not started / in progress / done), assignee, due date, priority, notes and repeats
- Closing a task closes its open subtasks after a two-step confirmation; closed tasks take no new subtasks
- Archive with restore, including unfinished tasks
- Private tasks, readable only by their owner (enforced by the database)
- Upcoming view (overdue, today, next 7 days, later) and an Activity feed of recent changes
- Comments, per-task history, "new for you" markers, drag-to-reorder
- Shopping lists: quick add with quantities, suggestions, automatic shop sections, basket, shopping mode, several lists
- Items to buy linked to tasks
- Smart add and "create tasks from text" using Claude
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

## Setup notes

- Supabase: sign-ups are off; people are invited under Authentication > Users. They sign in with
  email + password (set under People in the app) or with an emailed link/code.
- People > Your data: import an export file, download a backup, or delete all data for a clean start.

## Rules

- Never commit secrets (API keys, passwords, service credentials). They go in `.env` (ignored),
  Supabase secrets, or GitHub Secrets.
- Personal data exports live in `data/`, which Git ignores.
- Small commits with clear messages.
