# Our Tasks

A shared task tracker and shopping list for two people.

## Features

- Tasks nested to any depth, with status (not started / in progress / done), assignee, due date, priority, notes and repeats
- Closing a task closes its open subtasks after a two-step confirmation; closed tasks take no new subtasks
- Archive with restore, including unfinished tasks
- Private tasks, stored where only their owner can read them
- Upcoming view (overdue, today, next 7 days, later) and an Activity feed of recent changes
- Comments, per-task history, "new for you" markers, drag-to-reorder
- Shopping lists: quick add with quantities, suggestions, automatic shop sections, basket, shopping mode, several lists
- Items to buy linked to tasks
- Smart add and "create tasks from text" using Claude

## How it runs today

The whole app is one file, `index.html` (plain HTML, CSS and JavaScript, no build step).
It is published as a private claude.ai artifact:
https://claude.ai/artifact/YWak5qL6motHdVg6AqvjsC

Data lives in the artifact's document database (collections `tasks`, `comments`, `history`,
`items`, `lists`, `catalog`, `config/people`, and each person's private `data/users/<id>/…`).
All data access goes through the `store` object in `index.html`.

## Plan

1. Keep the code on GitHub (this repository).
2. Host the page on GitHub Pages.
3. Move the data to a database we control (Firebase or Supabase) for offline use and push notifications.

## Rules

- Never commit secrets (API keys, passwords, service credentials). They go in `.env` (ignored) or GitHub Secrets.
- Small commits with clear messages.
