---
name: foundry-init
description: >
  Initialize Foundry in a project. Creates .foundry/ dirs, foundry.json, and optionally scaffolds
  cascading AGENTS.md context system + doc gardening. One command for full project setup.
  Trigger: "init foundry", "set up foundry", "initialize foundry", first time in a project without foundry.json.
version: 0.2.0
---

# /foundry-init — Initialize Foundry in Project

One skill, two phases. Phase 1 (infrastructure) always runs. Phase 2 (cascading docs) is opt-in.

---

## Phase 1: Infrastructure

Always runs. Re-assesses tooling on repeat invocations.

### Steps

1. **Check if already initialized.** If `foundry.json` exists, note it — phase 1 will re-assess rather than skip.

2. **Create directories** (skip existing):
   - `.foundry/`
   - `.foundry/plans/`
   - `.foundry/executions/`
   - `.foundry/learned/`

3. **Create or update `foundry.json`:**
   - Detect `tsconfig.json` → enable typecheck (`npx tsc --noEmit --pretty`)
   - Detect `vitest.config.*` → enable test (`npx vitest run`)
   - Detect `jest.config.*` → enable test (`npx jest`). If both found, prefer Vitest.
   - Detect `.eslintrc*` or `eslint.config.*` → enable lint (`npx eslint .`)
   - Detect `.prettierrc*` or `prettier.config.*` → enable format (`npx prettier --write`)
   - Set `project.name` from `package.json` name or directory name
   - Set `project.description` from `package.json` description if available
   - Non-verification fields (`thresholds`, `features`) left at template defaults
   - **On re-run:** show diff if config would change, confirm before overwriting

4. **Create `foundry-progress.json`** if missing:
   ```json
   {
     "version": "0.1.0",
     "project": "<name>",
     "last_updated": "<ISO timestamp>",
     "current_phase": "",
     "tasks": [],
     "decisions": [],
     "blockers": []
   }
   ```

5. **Update `.gitignore`** (append if not already present):
   ```
   # Foundry
   .foundry/session-log.jsonl
   .foundry/handoff-note.md
   ```

6. **Report** what was created/updated and what tooling was detected.

### Re-run behavior

- Directories: skip existing (no-op)
- `foundry.json`: re-detect tooling, show diff if changed, ask to confirm update
- `foundry-progress.json`: skip if exists
- `.gitignore`: skip if entries already present

---

## Transition

After Phase 1 completes, prompt:

> "Want me to also set up cascading docs (AGENTS.md per directory + doc gardening)?"

- **Yes** → Phase 2
- **No** → Done, exit with report

---

## Phase 2: Cascading Docs (opt-in)

### Steps

1. **Assess current state:**
   - `CLAUDE.md` — absent, thin router, or monolith?
   - `AGENTS.md` files — any existing? (could be Codex convention)
   - `docs/decisions.md` — exists?
   - `.git/hooks/post-commit` — gardening already installed?
   - Report findings before proceeding.

2. **Propose directories for AGENTS.md:**
   - Scan for: source roots (`src/`, `app/`, `lib/`, `packages/*`), docs (`docs/`), config/infra (`.github/`, `deploy/`)
   - Include directories with 5+ files or clear domain boundaries
   - Present list to user for confirmation/adjustment

3. **Generate AGENTS.md** per confirmed directory:
   - Read code for gotchas, patterns, conventions
   - Check git log for pain points (reverts, fix commits)
   - Terse. <40 lines each. Every line earns its tokens.
   - Format: one-line description, Gotchas section, Patterns section, pointer to decisions.md
   - If AGENTS.md already exists in a dir: show proposed changes, don't overwrite silently

4. **Create or extract `decisions.md`:**
   - Monolith CLAUDE.md → extract ADRs into `docs/decisions.md`
   - No CLAUDE.md → scan for ADR-worthy patterns in code + git
   - Already exists → leave alone

5. **Create or refactor CLAUDE.md:**
   - Absent → create thin router (table of paths + AGENTS.md pointers, verify commands)
   - Monolith → extract into AGENTS.md + decisions.md, reduce to router. Show diff before writing.
   - Already thin router → add pointers for any new AGENTS.md files

6. **Install doc gardening:**
   - Resolve layer0 scripts path: check `FOUNDRY_LAYER0` env var, fall back to `~/.claude/scripts/` (where `install.sh` copies scripts)
   - Run `bash <scripts-path>/garden-setup.sh <project-dir>` (post-commit hook)
   - Ask about cron sweep (`--cron --interval N`)

7. **Report** everything created: AGENTS.md files + line counts, decisions.md status, CLAUDE.md status, gardening status.

---

## Behavior Matrix

| State | Phase 1 | Transition | Phase 2 |
|---|---|---|---|
| Fresh project | Full create | Ask | Full scaffolding |
| Has `foundry.json`, no docs | Re-assess, update if changed | Ask | Full scaffolding |
| Has `foundry.json` + docs | Re-assess, update if changed | Ask | Incremental (skip existing, offer update) |
| Has docs, no `foundry.json` | Full create | Ask (note docs exist) | Offer refresh of existing AGENTS.md |

---

## Rules

- Never overwrite `foundry.json` or existing AGENTS.md without showing diff and confirming
- Never commit `.foundry/session-log.jsonl` — ephemeral
- `foundry-progress.json` IS committed — cross-session source of truth
- Respect `.gitignore` — don't create AGENTS.md in ignored directories
- If existing AGENTS.md files found (Codex convention), read and integrate, don't replace
- AGENTS.md files must be <40 lines each
