# Our Tasks: backlog

Status: ✅ done · 🔶 partly done · ⬜ open. Effort: S (one session) · M · L.

## Notifications, briefings, voice

| | Item | Effort | Notes |
|---|---|---|---|
| ✅ | Push notifications on iPhone and Mac | | Own Web Push code in the `notify` function |
| ✅ | Instant: assigned to me, comments, closed by the other | | Per-person switches |
| ✅ | Morning briefing 7:30, evening check 20:00, written by Claude | | Times per person |
| ✅ | Briefing chat with suggested changes, applied on confirm | | |
| ✅ | Listen button and Talk (voice conversation) in the app | | |
| ✅ | Briefing language English / Polski | | |
| 🔶 | Natural-sounding spoken briefings | S | Better, keep tuning wording; optionally premium voices |
| ⬜ | Siri via Shortcuts: "Our briefing", "Ask Our Tasks" | M | Free, no developer account; private link per person |
| ⬜ | Editable quiet hours (fixed 22:00-7:00 today) | S | Columns exist in `notify_prefs` |
| ⬜ | Grouped "Wiola added 3 items to Groceries" notification | S | Not chosen yet |
| ⬜ | Reminders at a time of day (tasks with a time, not just a date) | M | Needs a due time field |
| ⬜ | Apple Calendar feed (subscribed calendar of due tasks) | M | Read-only, refresh 15 min to hours |
| ⬜ | Weekly summary e-mail via Gmail | M | Check Supabase mail ports first |
| ⬜ | Weekly review by Claude ("what's stuck, what to do this weekend") | S | Can reuse the briefing |

## Going live and bringing Wiola in ✅

| | Item | Effort | Notes |
|---|---|---|---|
| ✅ | Gmail as Supabase's mail sender (removes sign-in e-mail limit) | | In production and development |
| ✅ | Sign-in code in the Magic Link e-mail template | | |
| ✅ | Invite Wiola, her password, home-screen app, notifications | | Live since 25 Oct 2026 |
| ✅ | Clean start | | Production started with an empty database |
| ✅ | Error messages show the server's reason | | |
| ⬜ | Translate the app to Polish | M | Everything is English today |

## First week of real use (from 26 Oct 2026)

Notes from daily use go here, then we pick what to improve.

| | Item | Effort | Notes |
|---|---|---|---|
| ✅ | Ideas button in the app to collect feedback | | Migration 006; Copy open ideas → paste to Claude |
| ⬜ | Collect what's annoying or missing (Sławek and Wiola) | | Use the Ideas button |
| ⬜ | Check briefing times and tone for both | S | Times are per person under People |
| ⬜ | Show "I'm Wiola / I'm Sławek" link button in People when not linked | S | Today only the main screen offers it |

## From Ideas (25 Oct 2026)

| | Item | Effort | Notes |
|---|---|---|---|
| 🔶 | **Areas → Projects → Tasks** | M | Built on dev (migration 007, notify function updated); testing before production |
| ⬜ | **Checklists** (e.g. "Before we leave for the other home", "What to bring"): several lists like shopping lists, simple items with only done/not done, ticked items stay visible, closing the whole list archives it; frequent items per list; reusable versions of a list | M | Sławek. Reuse the shopping lists and items tables with a list type. Open question: closing = archive, or also "start again" (untick all) for lists used every trip? |
| ⬜ | **A colour per person**: Sławek and Wiola each get their own colour at the top (person filter) and everywhere their name appears (assignee, comments, activity, shopping "added by") | S | Sławek. Open question: which colours; pick them under People? |

### Design: Areas → Projects → Tasks (agreed 26 Oct 2026)

- **Area** = a theme that never finishes (e.g. a home, Insurance, Finances). Shown as a section header: no status,
  due date, assignee or "done"; the close cascade doesn't apply. Can be archived. Shows a count of open tasks.
  Ownership exactly like tasks: shared, or private to its owner.
- **Project** = any task that has tasks under it; not a separate kind. Shows progress ("7 of 12 done").
- **Task** = as today (subtasks, things to buy). Can sit directly under an area, without a project.
- Top level holds only areas. Quick add without an area goes to an **Inbox** to sort later.
- Filter by area; Today/Upcoming show "Area › Project" next to each task.
- From text / Smart add suggest an area and a new project (instead of "one new parent task"); briefings mention areas.
- No starting set: you create areas from scratch. Existing top-level tasks get moved under areas in the app.
- Covers the "Progress bar per project" item below.

## Working as a couple

| | Item | Effort | Notes |
|---|---|---|---|
| ✅ | Assign to each other, "new for you", activity feed, comments | | |
| ⬜ | "Who's doing what this week" overview | S | |
| ⬜ | Reactions and quick replies on comments | S | |
| ⬜ | Approvals ("OK to order this?") | M | |

## Tasks and projects

| | Item | Effort | Notes |
|---|---|---|---|
| ✅ | Nested tasks, statuses, close cascade, archive, private tasks | | |
| ✅ | Today view, My day, quick add, postpone, search everywhere | | |
| ✅ | Recurring tasks, default due date tomorrow | | |
| ✅ | Create tasks from text (one new parent task) | | |
| 🔶 | Progress bar per project | S | Part of Areas → Projects → Tasks |
| ⬜ | Templates (reusable checklists) | S | |
| ⬜ | Calendar view (month grid) | M | |
| ⬜ | Attachments and photos (quotes, invoices) | M | Supabase Storage |
| ⬜ | Cost tracking per project | M | |
| ⬜ | Break a task into steps with Claude | S | The chat can add tasks already |

## Shopping

| | Item | Effort | Notes |
|---|---|---|---|
| ✅ | Lists, sections, suggestions, smart add, shopping mode, items for tasks | | |
| ✅ | Frequent items per list | | |
| ⬜ | Private shopping items | S | Today all items are shared |
| ⬜ | Recurring shopping ("coffee every 2 weeks") | S | |
| ⬜ | Shop-specific order (learned from ticking order) | S | |
| ⬜ | Prices and budget per list / trip | M | |
| ⬜ | Photo of an item ("this exact brand") | M | Supabase Storage |

## Platform

| | Item | Effort | Notes |
|---|---|---|---|
| ✅ | Own hosting (GitHub Pages + Supabase), offline mode, app icon | | |
| ✅ | Separate production and development environments | | Two Supabase projects, `main` / `dev` branches |
| ✅ | Password and e-mail code sign-in | | |
| ⬜ | Native iPhone/Mac app: widgets, Siri intents, Watch | L | $99/year Apple Developer Program |
