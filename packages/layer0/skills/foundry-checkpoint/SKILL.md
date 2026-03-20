---
name: foundry-checkpoint
description: >
  Atomic save point: verify → review → commit → update progress → update codemap. Use after completing
  a logical unit of work. Trigger: "checkpoint", "save progress", "commit and update".
version: 0.2.0
---

# /foundry-checkpoint — Atomic Save Point

## What it does

Performs an atomic checkpoint: verify code, gate on evidence, commit changes, update progress. Use after each logical unit of work.

## Steps

1. **Verify** — run `/foundry-verify`. If any required check fails, STOP. Fix before checkpointing.

2. **Verification gate** — if Superpowers is installed, invoke `superpowers:verification-before-completion`. This forces you to prove the work is done with actual test/build output — no "should pass" claims.

3. **Stage changes** — `git add` relevant files. Never stage:
   - `.env`, credentials, secrets
   - `.claude/` directory
   - Lock files (unless intentional)
   - `.foundry/session-log.jsonl`

4. **Commit** — conventional commit format: `type(scope): description`
   - Derive type from changes (feat, fix, refactor, test, chore)
   - Keep message concise, focused on "why"

5. **Update progress** — update `foundry-progress.json`:
   - Mark completed tasks
   - Update `last_updated` timestamp
   - Add any decisions made during this unit of work

6. **Update codemap** (if `features.auto_codemap` enabled in foundry.json):
   - Regenerate `.foundry/codemap.md`

7. **Report** checkpoint result:
   ```
   Checkpoint: feat(auth): add JWT validation middleware
   - Verify: PASS (typecheck 1.2s, test 3.4s)
   - Committed: abc1234
   - Progress: 3/7 tasks complete
   ```

## Arguments

- No args: checkpoint with auto-detected commit message
- `$ARGUMENTS`: override commit message

## Important

- NEVER checkpoint with failing verification — that defeats the purpose
- Keep commits granular — one logical change per checkpoint
- If the bob gate is active, ensure `/bob --staged` passes before committing
