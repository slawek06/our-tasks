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

## Going live and bringing Wiola in

| | Item | Effort | Notes |
|---|---|---|---|
| ⬜ | Gmail as Supabase's mail sender (removes sign-in e-mail limit) | S | Gmail app password, Authentication > SMTP |
| ⬜ | Sign-in code in the Magic Link e-mail template | S | Works once custom SMTP is on |
| ⬜ | Invite Wiola, her password, home-screen app, notifications | S | |
| ⬜ | Clean start: backup, then Delete all data | S | Buttons exist under People > Your data |
| ⬜ | Translate the app to Polish | M | Everything is English today |

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
| ⬜ | Progress bar per project | S | |
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
