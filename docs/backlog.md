# Our Tasks: backlog

Status: ✅ done · 🔶 partly done · ⬜ open · ➖ dropped. Effort: S (one session) · M · L.

**The owner's plan (31 Oct 2026):** 1) finish and close Release 3; 2) detail the Assistant and build it; 3) then decide the way forward: native route, new look, own server.

Release in progress: **Release 3** (Thanks, already in production; Wrap up all areas, built; the supabase-js checksum and an icon on every task, built; Remember an item's photo, planned). Numbering decided 30 Oct 2026; earlier releases go by their date.

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
| ✅ | Editable quiet hours | S | Released 30 Oct 2026 (no migration, notify updated). Two times per person under People, on their own clock, default 22:00 to 07:00; may cross midnight; the same time twice or a cleared time means none. Reminders you set yourself ring through them, except 24 hours before (decided 30 Oct 2026); the rest wait until they end. Decided 30 Oct 2026: briefings keep the time you chose, even inside quiet hours |
| ➖ | Grouped "Wiola added 3 items to Groceries" notification | S | Dropped 30 Oct 2026, the owner's decision |
| ✅ | Reminders at a time of day (tasks with a time, not just a date) | M | Released 30 Oct 2026 (migration 013, notify updated). Decided 30 Oct 2026: the date and time say when the thing happens; reminders are chosen before it: 24 hours, 1 hour, 15 minutes, at the time, several allowed, starting with 1 hour before when a time is set (none ticked = no reminder). Timer every 5 minutes (at most about 5 minutes late). Quiet hours: only your own reminder can wake you: 24 hours before and reminders the other person set wait until they end (dropped if the event is over by then); shorter ones you set yourself ring anyway. Each person has a Task reminders switch under People. A shared task with nobody assigned reminds both; private tasks only the owner. A moment that has passed isn't sent. Time set in the editor or quick add ("at 9:05"); the chat and From text set dates only (could follow) |
| ⬜ | Apple Calendar feed (subscribed calendar of due tasks) | M | Read-only, refresh 15 min to hours |
| ⬜ | Weekly summary e-mail via Gmail | M | Check Supabase mail ports first |
| ⬜ | Weekly review by Claude ("what's stuck, what to do this weekend") | S | Can reuse the briefing |
| ⬜ | **Assistant**: the briefing chat becomes an always-reachable private assistant, built with Claude first and moved to the local model later | S-M | Proposed 31 Oct 2026; later, after the small items (the owner's decision). Adds to today's chat: times and reminders; rename, note, comment (with @mention) and reopen; thanks for a task the other person closed; asks when two tasks could match. Every change still needs a Confirm tap. Selective sending: a short list by default, Claude searches for more, shopping only when needed, a per-person switch for private tasks, off by default, also applied to briefings. Keep the AI behind one function and collect real requests as a test set, so the model can be swapped. No migration; notify changes. The shared chat stays separate and parked |
| ⬜ | Assistant memory: notes it remembers, per person, each confirmed, visible and editable | S-M | After the Assistant (proposed 31 Oct 2026). Stored in our database, so it carries over to a local model. Habits later, also confirmed; never judgements of a person. Needs a migration |
| ⬜ | Flowers for no reason: thanks not tied to a closed task | S | Idea, 31 Oct 2026. Needs a migration and a place in the app to show them |

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

## From Ideas (25 Oct 2026)

| | Item | Effort | Notes |
|---|---|---|---|
| ✅ | **Areas → Projects → Tasks** | | Live 26 Oct 2026 (migration 007, notify function updated) |
| ✅ | **Checklists** (Sławek): see the design below | | Released 29 Oct 2026 (migration 008) |
| ✅ | **A colour per person**: Sławek blue, Wiola green, at the top and wherever a name appears | | Released 29 Oct 2026 |
| ✅ | **New tasks belong to whoever creates them** (unless you pick or name someone else) | | Released 29 Oct 2026; replaced by the rule below on 30 Oct 2026 |
| ✅ | **Every task has an owner**: new tasks default to Both; a task under another task and a next step inherit from the task above; directly under an area = Both; "No one" removed; existing unassigned tasks become Both once; "Due, but nobody's assigned" removed from Today. Naming someone still wins; private tasks and areas unchanged | S | Next release (decided 30 Oct 2026). **No push for Both**: an assignment push only when the other person is picked by name; Both still shows as new in the app. Released 30 Oct 2026 (migration 014, notify changed). Decisions: the no-push rule lives in `notify`, one place; closed and archived tasks stay empty in the database and show as Both (history isn't rewritten, and 014 can't mark anything as new); inheriting from a task of the other person's does push, since it is theirs by name; subtasks of a private task made shared take its person |

### Design: Checklists (agreed 26 Oct 2026)

- Lives in a **Lists** tab with two parts: Shopping and Checklists (no seventh tab).
- **Templates** are the reusable versions ("Leaving Warsaw → Kraków", "Ski trip packing"); never ticked.
- **Start** a template → a fresh list ("Leaving Warsaw · Fri 31 Oct"); blank one-off lists too.
- Items are text + done only. Ticked items stay visible (struck through) with the initial of who ticked it (trial: keep it?).
- Headings inside a list: a line ending with ":" (e.g. "Before we go:", "Bring:").
- Frequent suggestions: this template's past lists first, then all lists.
- **Close list** archives it (asks if items are open) and offers to add items added during the trip to the template.
- Closed lists stay viewable. Shared or private like tasks. Works offline.
- Item actions: send to Shopping, make it a task.
- "+ Add here" on a heading puts new items under it; drag (or arrow keys) to move items and headings.
- Later: belong to an area and show in Today; Claude drafts a template;
  standing lists (never closed, for "To talk about"); templates that start on a schedule.

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

⭐ = top picks (most effect for the effort). Ideas collected 26 Oct 2026, for the future.

| | Item | Effort | Notes |
|---|---|---|---|
| ✅ | Assign to each other, "new for you", activity feed, comments | | |
| ➖ | **"I'm going to the shop"**: one tap tells the other person, items they add appear live | S | Dropped 30 Oct 2026: not practical for us |
| ➖ | **"Can you take this?"**: ask instead of assign; Take it / Can't, because… | S | Dropped 30 Oct 2026: the owner doesn't think we need it |
| ✅ | **Seen markers**: "Wiola saw it 10:42" on assigned tasks and comments | S | Released 30 Oct 2026 (migration 011). Shown in the task editor: on tasks you assigned to the other person and on your comments; the time is when they first opened it. Not on task rows (could follow) |
| ✅ | **Mentions in comments**: @Wiola sends her a push | S | Released 30 Oct 2026 (notify updated). Decided 30 Oct 2026: typing @ offers the other's name, shown in their colour; a mention pushes even with their Comments switch off, titled "Sławek mentioned you in …", one push only; quiet hours still apply; no new switch, not in the briefing |
| ➖ | **Gentle nudge**: "Remind Wiola" push worded by Claude, at most once a day per task | S | Dropped 30 Oct 2026, the owner's decision |
| ✅ | **"To talk about" list**: a standing checklist (never closed); shows who raised each topic; tick when discussed, then Clear ticked; briefings may mention topics | | Released 29 Oct 2026 (migration 009) |
| ⬜ | **Our week**: who's doing what this week and what each finished, incl. planning and shopping; awareness, not scorekeeping | S | Replaces "Who's doing what this week" |
| ✅ | ⭐ **"Thanks ❤️"**: one-tap thanks for a task the other person closed | S | Part of Release 3, already in production since 30 Oct 2026 (migration 017, notify changed). The owner confirmed it works. Decided 30 Oct 2026: 14 pictures in two rows, flowers, heart and sun, then "for the boy" (beer, coffee, pizza, muscle, trophy, wrench, car); anyone can send any of them. iPhones show no buttons on a web app's notifications, so tapping the "closed" push opens the task, where the pictures are near the top. Also reached from Activity or the task's row. One per person per task: another picture replaces it, the same one takes it back, and only the first one pushes. The push follows the Comments switch and quiet hours. Shows on the task's row, in the editor and in Activity; never on private tasks. Who closed it comes from the history |
| ⬜ | ⭐ **Weekly check-in with Claude**: 10-minute Sunday conversation (done, stuck, to talk about, who takes what), changes applied on confirm | M | Top pick; builds on the briefing chat |
| ⬜ | Quick replies on comments | S | |
| ✅ | **Done + next step**: closing a task offers a follow-up task (same area/project, link "Follow-up of …"); the outcome is saved as a comment | S | Released 30 Oct 2026 (migration 012). Decided 30 Oct 2026: closing stays one tap, the toast offers "Next step"; the editor has "Done + next step" (open tasks) and "Add a next step" (closed ones). The task closes first, so Skip leaves it closed. The form asks for the outcome (optional, saved once) and one or more next steps: "+ Another step" adds a row of title, date (tomorrow) and person (you), no limit, and a row without a title is ignored. Each step is its own task (several steps added 30 Oct 2026, the owner's request after trying one). An outcome without a title saves just the outcome. Private tasks have no comments, so their outcome goes in the notes; their follow-up is private. Links show in the editor only, not on task rows (could follow). Comment and assignment pushes work as usual |
| ⬜ | **Our chat with a local AI**: a shared chat that turns into tasks, plus a private side; see the design below | L | Waiting for the owner's local AI model, expected about 2-3 months from 30 Oct 2026. Decided 30 Oct 2026: for privacy, the chat isn't sent to Anthropic |
| ⬜ | Done + next step, extras: Claude suggests the next step's title and date from the outcome; the briefing mentions follow-ups | S | Options left out of the first version, waiting for the owner's decision (30 Oct 2026). Suggestion: `claude` function; briefing: `notify` redeploy |

### Design: Our chat with a local AI (concept, 30 Oct 2026, not final)

- **Us**: the shared chat, with photos, push and seen markers. The AI offers one-tap cards for tasks, shopping items, dates and reminders, answers @questions from shared data, and offers to save decisions on the task or area. A comment on a task also shows in the chat.
- **Just me**: private to each person, with reminders about your own tasks and promises, private questions, and the briefings.
- **Rules**: the database keeps Just me private. In Us the AI gets shared data only. Nothing changes without a tap. It never compares people, comments on tone or passes on what was said in private.
- **Local AI**: runs on the owner's computer and fetches new messages from Supabase itself, so no router ports are opened. It has its own limited access, not the service role key. If the computer is off, the chat and existing reminders keep working and only the AI waits.
- **Before building**: Wiola agrees; try the model on real Polish and English examples, including dates like "w czwartek".
- **Stages**: 1) chat, @questions, press a message to make a task, briefings in Just me. 2) The AI suggests by itself, private reminders about promises. 3) Saved decisions and search across old messages, weekly check-in.
- **Absorbs when built**: Thanks ❤️ and quick replies become chat actions.
- **Open**: where the chat sits (no seventh tab so far); whether briefings, Smart add and From text also move to the local AI, since they send data to Anthropic today.

## Tasks and projects

| | Item | Effort | Notes |
|---|---|---|---|
| ✅ | Nested tasks, statuses, close cascade, archive, private tasks | | |
| ✅ | Today view, My day, quick add, postpone, search everywhere | | |
| ✅ | Recurring tasks, default due date tomorrow | | |
| ✅ | Create tasks from text (one new parent task) | | |
| ✅ | Progress bar per project | | Part of Areas → Projects → Tasks |
| ✅ | Templates (reusable checklists) | | Covered by Checklists |
| ✅ | **Quick archive**: a button on a closed task's row moves it to the archive without opening it | S | Released 30 Oct 2026 (the owner's request). One tap with Undo; asks first only if a subtask is still open. No migration. The My day clock on open rows was invisible on phones since 25 Oct 2026 and now shows too, the same way as add subtask |
| 🔶 | **Wrap up all areas**: one tap closes every area, so you can open just the one you want | S | Built on dev for Release 3 (the owner's request). No migration. A link above the areas in the Tasks tab, shown with two or more areas: "Wrap up all", then "Open all". Each device remembers it for each person. Decided: areas now stay closed under Hide done and a person's filter too (they used to open by themselves); a search still looks inside them |
| 🔶 | **An icon on every task**: Claude picks an emoji that fits the task's name, for fun | S-M | Built on dev for Release 3 (the owner's idea, 31 Oct 2026; migration 018, notify changed). Decided: emoji, not generated images; picked by Claude Haiku 5.5 (the cheapest model, chosen by the owner for this job), up to 40 tasks per run of the 5-minute timer, so up to 5 minutes late but covering every way of adding a task; existing open and closed tasks get one too, not archived ones or areas. Fully automatic, the owner's decision: no picker or way to change an icon in the app. Renaming a task gets it a new icon on the next run. Private tasks never go to Claude, so they have no icon. Estimated under 1 cent per 100 tasks. Claude's picks not yet tried: needs the migration and notify in development |
| ⬜ | Calendar view (month grid) | M | |
| ✅ | **Attachments and photos** (quotes, invoices) | M | Released 30 Oct 2026 (migration 016). Decided 30 Oct 2026: photos (JPEG, PNG, HEIC, stored as a shrunk JPEG, up to about 1.5 MB) and PDFs up to 10 MB; up to 10 per task, saved tasks only. Closed and archived tasks keep their files (archived: look only); deleting a task removes them for good. Either person can remove a file on a shared task, with Undo. Push to the other person, under the Comments switch, never for private tasks. A file seen once stays on the phone for use without signal; adding needs a connection. Could follow: storage used shown in the app, attaching while creating a task |
| ⬜ | Break a task into steps with Claude | S | The chat can add tasks already |

## Shopping

| | Item | Effort | Notes |
|---|---|---|---|
| ✅ | Lists, sections, suggestions, smart add, shopping mode, items for tasks | | |
| ✅ | Frequent items per list | | |
| ✅ | Private shopping lists (whole list private; private items not needed) | | Released 29 Oct 2026 (migration 009) |
| ➖ | Recurring shopping ("coffee every 2 weeks") | S | Dropped 30 Oct 2026, the owner's decision |
| ➖ | Shop-specific order (learned from ticking order) | S | Dropped 30 Oct 2026: too complex; the owner finds the sorting we have enough |
| ✅ | Photo of an item ("this exact brand") | M | Released 30 Oct 2026, migration 015. Decided: one photo per item (a new one replaces it), camera or library; it goes with the item (Finish shopping, Remove, deleting the list; Undo brings it back; an item bought for a task keeps it); a small picture on the row, tap for large; the phone keeps a copy so photos show in a shop without signal, deleted on sign-out; adding needs a connection. Shrunk on the phone to 1280 pixels (1 GB holds thousands). Private rules follow the item; the server removes unused files once a day |
| ⬜ | Remember an item's photo for next time ("coffee" brings back its photo) | S | Chosen for Release 3, not started (decided 30 Oct 2026, the owner's request: a new photo replaces the remembered one; removing a photo forgets it). Left out of the first version because photos would pile up and need rules of their own on private lists. Needs migration 018: the daily clean-up must keep remembered photos, and their access rules can't go by the item alone |

## Platform

| | Item | Effort | Notes |
|---|---|---|---|
| ✅ | Own hosting (GitHub Pages + Supabase), offline mode, app icon | | |
| ✅ | Separate production and development environments | | Two Supabase projects, `main` / `dev` branches |
| ✅ | Password and e-mail code sign-in | | |
| ⬜ | Native iPhone/Mac app: widgets, Siri intents, Watch | M-L | Route not decided; see the options below. $99/year Apple Developer Program |
| ⬜ | Small native test: the Today screen in Swift with real tasks and one widget, to try on the owner's iPhone | S-M | Decides between B and C below. Needs the Apple account |
| ⬜ | **New look for the app** | L | Mockups of the Today screen: https://claude.ai/artifact/X7wTeraLA3jZC7RTNBVmud (private, three proposals: Calm, The two of us, Agenda). Works on today's technology, no database or function changes apart from task icons. Seen so far: tasks start too low, tabs run off the screen, rows are busy, the editor is one long form. Not started: decide after the native route, since a full native move would use the design but not the web build |
| ⬜ | **Own server on a Mac mini**: run the local AI, and perhaps the whole app, at home; see the plan below | L | Major project, not for the coming weeks (the owner's decision, 31 Oct 2026). Supabase stays until a test copy has proved itself |
| ✅ | One-file database update for a release (`scripts/make-release-sql.py`) | S | Decided 30 Oct 2026, after a migration went to the wrong project: one file per project, migrations plus the privacy check, refuses to run in the wrong project. Used for the releases of 30 Oct 2026 and Release 3 |

### Options: native apps (31 Oct 2026, not decided)

| | A. Web app, as today | B. Web app in a native shell | C. Fully native (Swift) |
|---|---|---|---|
| Widgets | No | Yes | Yes |
| Siri, Watch | Shortcuts only | Siri possible; Watch needs its own app | Yes |
| Feel | Good | About the same on iPhone; Mac like a web page in a window | The best |
| Work | None | M | The largest item by far: screens and offline rebuilt |
| Fix or feature | Live in minutes | Live in minutes | A new build each time; slower |

- B and C both need: $99 a year, Xcode, TestFlight (builds expire after 90 days; App Store adds a review), and native pushes (`notify` changes, an Apple key the owner stores in Supabase).
- B carries over to C: the widgets, native pushes and Apple setup stay.
- To test: whether iPhone widgets on the Mac desktop are enough, so no Mac app is needed; how a Mac shell holds up.
- Widgets show tasks on the Home Screen and desktop: mind private tasks.

### Plan: own server on a Mac mini (concept, 31 Oct 2026, not final)

The owner's setup: a full-spec Mac mini as the server, connected to a Synology NAS over 10 Gb LAN, Tailscale for access, a UPS for power cuts. The NAS has a full online backup. Most Synology models are too weak for the AI model, so it runs on the Mac mini.

1. **Now**: finish Release 3 and keep Supabase running the app. Export monthly to the NAS (see Security).
2. **When the Mac mini arrives**: run the local AI there, still with Supabase. "Our chat with a local AI" waits for this; it can also take over briefings, Smart add and From text, so nothing goes to Anthropic.
3. **A test copy**: run the orange app on the Mac mini for a few weeks, with the blue app staying on Supabase.
4. **Only then decide**: if it has been stable for both, move the blue app and keep the last Supabase copy as a fallback for a while.

- **Gains**: reachable only from your own devices, data at home, easy backups to the NAS, no Anthropic once the local AI is in place.
- **Remaining costs**: a home internet failure stops syncing (offline mode softens it; reminders arrive late); Tailscale must be connected on both iPhones; a new app address means installing the app and turning on notifications again; the owner becomes the administrator (updates, restarts, checking backups).
- **To test first**: Supabase in Docker on a Mac stays reliable; pushes work from there; the router is on the UPS.
- **Before starting**: Wiola agrees. As administrator the owner could technically read their private items, as is already possible in the Supabase dashboard, and they should know that.

## Security (review 26 Oct 2026)

Outsiders get nothing without a sign-in; the weak points are the accounts around the app, not the code.

| | Item | Effort | Notes |
|---|---|---|---|
| ✅ | Comments and history of a private task readable only by its owner | | Released 29 Oct 2026 (migration 010) |
| ✅ | Fix: items of a private shopping list were readable by the other person | | 009's rule checked the list through its own access rule; fixed in 010. Released 29 Oct 2026; never live without 010 |
| ✅ | History no longer names items added to a private list | | Migration 010 also rewrites older entries. Released 29 Oct 2026 |
| ✅ | Signing out deletes the device copy of the data (warns about unsent offline changes) | | Released 29 Oct 2026 |
| ✅ | notify answers errors without technical details (they go to its logs) | | Released 29 Oct 2026 |
| ✅ | Privacy check script | | `supabase/tests/privacy-check.sql`: PASS/FAIL per rule, leaves nothing behind |
| 🔶 | Two-step sign-in on Gmail (both), Supabase, GitHub, Anthropic | S | Done: Sławek's Gmail, GitHub (27 Oct 2026). Open: Wiola's Gmail, Supabase (authenticator app). Anthropic has no own setting: sign-in goes through Gmail, so Gmail's two-step covers it |
| ✅ | Monthly spending limit on the Anthropic key | S | Set to $5 a month (27 Oct 2026), console.anthropic.com → Settings → Limits |
| ⬜ | Own backup: export once a month (People → Your data) into `data/` and to the NAS | S | Free plan has no restorable backups. The NAS's online backup then protects that copy too. To check: whether the export includes photos and files |
| ⬜ | Automatic backup to the NAS: the NAS downloads a copy of the database on a schedule | M | Idea, 31 Oct 2026. A full copy includes Wiola's private items, so it must be encrypted with a key agreed together, and Wiola must agree. The database password would be stored on the NAS, entered by the owner, so the NAS needs two-step sign-in. Becomes simple if the app moves to the Mac mini. Parked for later (31 Oct 2026). Thinking so far: the NAS starts it (Task Scheduler), since it needn't be reachable from outside; one script does `pg_dump`, downloads Storage files (a database copy leaves them out), encrypts with a key the NAS can't unlock, and keeps 7 daily, 4 weekly and 12 monthly copies; Snapshot Replication and Hyper Backup protect the folder. Not Cloud Sync: it would leave private files readable. Alert on failure and warn when no backup has finished for a couple of days. A read-only database login. Test restore after setup. Not tried against the project yet |
| ⬜ | Separate web address for dev (dev and production share `slawek06.github.io`, so their browser storage) | M | Decided: leave; only our own code runs there |
| 🔶 | Checksum (SRI) on the supabase-js script from jsDelivr | S | Built on dev for Release 3 (no migration or function change). The browser refuses the file unless it's exactly version 2.45.4; the fingerprint matches an independent copy from unpkg. If it were ever refused, the app says "Couldn't reach the server". The owner tried it on a real iPhone, online and in Airplane Mode: it works (31 Oct 2026) |
