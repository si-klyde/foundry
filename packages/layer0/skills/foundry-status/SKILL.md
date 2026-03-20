---
name: foundry-status
description: >
  Quick project overview: plan progress, changed files, recent decisions, verification state.
  Trigger: "status", "where are we?", "what's the state?", "overview".
version: 0.1.0
---

# /foundry-status — Project Status Overview

## What it does

Provides a quick snapshot of project state without modifying anything.

## Steps

1. **Read `foundry-progress.json`** — summarize:
   - Current phase
   - Task counts: completed / in-progress / blocked / pending
   - Recent decisions (last 3)
   - Open blockers

2. **Check active plan** — if `.foundry/active-plan.json` exists:
   - Plan name and status
   - Current task
   - Tasks remaining

3. **Git state:**
   - Current branch
   - Uncommitted changes count
   - Last 3 commits (one-line)

4. **Verification state** — if recently run, report last results. Otherwise note "not verified since last change."

5. **Output** concise status:
   ```
   ## Foundry Status
   Phase: Phase 2 — Core Skills
   Progress: 5/12 tasks (2 in-progress, 1 blocked)
   Plan: auth-middleware (approved, task 3/5)
   Branch: feat/auth-middleware (3 uncommitted files)
   Last commit: abc1234 feat(auth): add JWT validation
   Verify: PASS (2m ago)
   Blockers: 1 open — API rate limit unclear
   ```

## Important

- This is read-only — never modify state
- Keep output concise — status should be glanceable
- If no foundry.json exists, suggest running `/foundry-init`
