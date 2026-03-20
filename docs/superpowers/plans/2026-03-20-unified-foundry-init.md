# Unified `/foundry-init` Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge `/foundry-init` and `/foundry-docs` into a single two-phase `/foundry-init` skill, then clean up all references.

**Architecture:** One SKILL.md file replaces two. Phase 1 (infrastructure) always runs, Phase 2 (cascading docs) is opt-in. No code — all changes are markdown skill definitions and reference updates.

**Tech Stack:** Markdown, shell (install.sh)

**Spec:** `docs/superpowers/specs/2026-03-20-unified-foundry-init-design.md`

---

## File Structure

| File | Action | Purpose |
|---|---|---|
| `packages/layer0/skills/foundry-init/SKILL.md` | Rewrite | Unified skill with both phases |
| `packages/layer0/skills/foundry-docs/SKILL.md` | Delete | Replaced by unified init |
| `packages/layer0/install.sh` | Edit | Remove `foundry-docs` from SKILLS array |
| `packages/layer0/rules/integration.md` | Edit | Update ownership table |
| `docs/progress.md` | Edit | Remove foundry-docs row, update skill count, update next steps |
| `docs/foundry-harness-prd-v3.md` | Edit | Update section 0.9 + ownership table |
| `~/.claude/CLAUDE.md` | Edit | Update context system reference |

---

## Chunk 1: Core Skill Changes

### Task 1: Rewrite `/foundry-init` SKILL.md

**Files:**
- Rewrite: `packages/layer0/skills/foundry-init/SKILL.md`

- [ ] **Step 1: Read current SKILL.md**

Read `packages/layer0/skills/foundry-init/SKILL.md` to confirm current content before overwriting.

- [ ] **Step 2: Write unified SKILL.md**

Replace entire file with the unified two-phase skill. The new version must:

1. Update frontmatter: version `0.2.0`, description mentions both infrastructure and cascading docs
2. Phase 1 section — infrastructure steps (directories, foundry.json detection, progress file, .gitignore)
3. Re-run behavior — re-detect tooling, show diff, confirm
4. Transition prompt — ask about cascading docs
5. Phase 2 section — assess state, propose dirs, generate AGENTS.md, decisions.md, CLAUDE.md, gardening
6. Behavior matrix — all four states
7. Rules section — safety constraints

Content for the new SKILL.md:

```markdown
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
```

- [ ] **Step 3: Verify the file was written correctly**

Read back `packages/layer0/skills/foundry-init/SKILL.md` and confirm it starts with the `---` frontmatter, has version `0.2.0`, and contains both Phase 1 and Phase 2 sections.

- [ ] **Step 4: Commit**

```bash
git add packages/layer0/skills/foundry-init/SKILL.md
git commit -m "feat(foundry-init): unify init + docs into single two-phase skill"
```

---

### Task 2: Delete `/foundry-docs` skill

**Files:**
- Delete: `packages/layer0/skills/foundry-docs/SKILL.md`
- Delete: `packages/layer0/skills/foundry-docs/` (directory)

- [ ] **Step 1: Delete the directory**

```bash
rm -rf packages/layer0/skills/foundry-docs
```

- [ ] **Step 2: Verify deletion**

Confirm `packages/layer0/skills/foundry-docs/` no longer exists.

- [ ] **Step 3: Commit**

```bash
git add -A packages/layer0/skills/foundry-docs
git commit -m "chore: remove foundry-docs skill (merged into foundry-init)"
```

---

## Chunk 2: Reference Cleanup

### Task 3: Update install.sh

**Files:**
- Modify: `packages/layer0/install.sh:19`

- [ ] **Step 1: Remove `foundry-docs` from SKILLS array**

In `packages/layer0/install.sh`, line 19, change:
```bash
  foundry-benchmark foundry-review foundry-clean foundry-docs
```
to:
```bash
  foundry-benchmark foundry-review foundry-clean
```

This changes the skill count from 16 to 15.

- [ ] **Step 2: Update install output**

The install output on line 123 says `${#SKILLS[@]} skills` — this auto-calculates, so no change needed. Same for uninstall on line 58. Just verify the array change is correct.

- [ ] **Step 3: Commit**

```bash
git add packages/layer0/install.sh
git commit -m "chore(install): remove foundry-docs from skill list"
```

---

### Task 4: Update integration.md rule

**Files:**
- Modify: `packages/layer0/rules/integration.md:7`

- [ ] **Step 1: Update ownership line**

Change `/foundry-docs` to `/foundry-init` in the Foundry ownership line:

```
doc scaffolding (/foundry-docs)
```
→
```
doc scaffolding + project init (/foundry-init)
```

- [ ] **Step 2: Commit**

```bash
git add packages/layer0/rules/integration.md
git commit -m "chore(rules): update integration.md ownership table"
```

---

### Task 5: Update progress.md

**Files:**
- Modify: `docs/progress.md:45,57,152-162,185`

- [ ] **Step 1: Update skill table**

Line 57 — remove the `foundry-docs` row:
```
| foundry-docs | Core |
```
Delete this row entirely.

- [ ] **Step 2: Update skill count**

Line 45 — change `### Skills (16 + 1 bootstrap)` to `### Skills (15 + 1 bootstrap)`.

- [ ] **Step 3: Merge foundry-docs section into foundry-init context**

Lines 152-161 — the `/foundry-docs` skill section. Replace with a note under the cascading AGENTS.md section (line 129+) that docs scaffolding is now part of `/foundry-init` Phase 2.

Remove:
```markdown
### `/foundry-docs` skill

Scaffolds the cascading context system in any project:
1. Assess current state (no CLAUDE.md / monolith / existing AGENTS.md)
2. Propose key directories for AGENTS.md — user confirms
3. Generate AGENTS.md by reading code + git history
4. Create/extract decisions.md
5. Create or refactor CLAUDE.md into thin router
6. Set up doc gardening (post-commit hook + optional cron)

Global CLAUDE.md updated with Context System section — agent knows to check for AGENTS.md in unfamiliar dirs and offer scaffolding before session ends.
```

Replace with a single line in the cascading AGENTS.md section:
```markdown
Docs scaffolding merged into `/foundry-init` Phase 2 (v0.2.0).
```

- [ ] **Step 4: Update next steps**

Line 185 — change:
```
3. Dogfood `/foundry-docs` — run on a project without cascading context
```
to:
```
3. Dogfood `/foundry-init` Phase 2 — run on a project without cascading context
```

- [ ] **Step 5: Commit**

```bash
git add docs/progress.md
git commit -m "chore(progress): update for unified foundry-init"
```

---

### Task 6: Update foundry-harness-prd-v3.md

**Files:**
- Modify: `docs/foundry-harness-prd-v3.md:138,152`

- [ ] **Step 1: Update section 0.9 reference**

Line 138 — change:
```
`/foundry-docs` skill scaffolds the pattern in any project.
```
to:
```
`/foundry-init` Phase 2 scaffolds the pattern in any project.
```

- [ ] **Step 2: Update ownership table**

Line 152 — change:
```
| Doc scaffolding (foundry-docs) | Code review (requesting/receiving-code-review) |
```
to:
```
| Doc scaffolding + project init (foundry-init) | Code review (requesting/receiving-code-review) |
```

- [ ] **Step 3: Commit**

```bash
git add docs/foundry-harness-prd-v3.md
git commit -m "chore(prd): update v3 for unified foundry-init"
```

---

### Task 7: Update global CLAUDE.md

**Files:**
- Modify: `~/.claude/CLAUDE.md:18`

- [ ] **Step 1: Update context system reference**

Line 18 — change:
```
- Projects without cascading context: use `/foundry-docs` to scaffold
```
to:
```
- Projects without cascading context: use `/foundry-init` to scaffold (Phase 2)
```

- [ ] **Step 2: Verify**

Read back `~/.claude/CLAUDE.md` and confirm the line was updated. Note: this is a global file outside the repo — do NOT commit this. The install script handles it on reinstall.

---

### Task 8: Reinstall and verify

- [ ] **Step 1: Run install.sh**

```bash
bash packages/layer0/install.sh
```

Verify output shows 15 skills (not 16) and no errors.

- [ ] **Step 2: Verify foundry-docs is gone from ~/.claude/skills/**

```bash
ls ~/.claude/skills/ | grep foundry
```

Should NOT contain `foundry-docs`. Should contain `foundry-init`.

- [ ] **Step 3: Verify foundry-init skill content**

```bash
head -5 ~/.claude/skills/foundry-init/SKILL.md
```

Should show version `0.2.0` and updated description.

---

## Summary

| Task | What | Commit |
|---|---|---|
| 1 | Rewrite foundry-init SKILL.md (unified) | `feat(foundry-init): unify init + docs into single two-phase skill` |
| 2 | Delete foundry-docs skill | `chore: remove foundry-docs skill (merged into foundry-init)` |
| 3 | Update install.sh | `chore(install): remove foundry-docs from skill list` |
| 4 | Update integration.md | `chore(rules): update integration.md ownership table` |
| 5 | Update progress.md | `chore(progress): update for unified foundry-init` |
| 6 | Update PRD v3 | `chore(prd): update v3 for unified foundry-init` |
| 7 | Update global CLAUDE.md | No commit (global file, handled by install) |
| 8 | Reinstall + verify | No commit |
