# Our Tasks: working rules for Claude

A shared task tracker, shopping lists and checklists for two people. Read these first:
- `docs/architecture.md`: how it's built and configured, environments, rebuild guide
- `docs/backlog.md`: plans, decisions and designs, with status
- `README.md`: short overview
- `CLAUDE.local.md` (not in Git, may be missing): private notes and the release in progress

## The owner
Doesn't write code (was a developer long ago: C, C++, Java, databases). Explain in plain words, give step-by-step
instructions with exact menu paths and links for anything to do in Supabase or GitHub, and say what to check after.

## Never
- Ask for, handle or commit secrets: database password, `sb_secret` / service role key, Anthropic API key, Gmail app
  password. Publishable keys are public and fine. Secrets live only in Supabase (and GitHub Secrets if ever needed).
- Put a real name or email on GitHub. Commits use the repo-local identity `slawek06`
  / `89165628+slawek06@users.noreply.github.com`; don't change it.
- Commit personal data (`data/` is ignored).

## Workflow
- Work on the `dev` branch; GitHub Actions publishes it to https://slawek06.github.io/our-tasks/dev/ (orange app).
- `main` is production (https://slawek06.github.io/our-tasks/, blue app). Changes reach it only in a **release**:
  several items collected on `dev`, then merged together when the owner says so.
- Database changes: a new numbered file in `supabase/migrations/`, safe to run more than once; the app hides the
  feature until it has run. Run in development first; list it for the release. Regenerate the production setup file
  with `python3 scripts/make-setup-sql.py jwhuaaxrymdqwanwthvg`.
- Edge Functions (`supabase/functions/*`) are deployed by the owner by pasting the code in the dashboard: say which
  function and which project.
- Test changes in the local preview (`.claude/launch.json`, preview mode keeps data in the browser) at phone size
  before publishing; clear test data afterwards.
- Match the existing code style: one `index.html`, plain JavaScript, the `h()` / `fill()` helpers, `store` for data.

## Keep the docs current
Every change updates, in the same commit:
- `docs/architecture.md`: structure, data model, functions, configuration, the migrations table per environment
- `docs/backlog.md`: status (✅ done · 🔶 built on dev / partly · ⬜ open) and new decisions
- `CLAUDE.local.md`: the release in progress
