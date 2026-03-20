---
name: foundry-handoff
description: >
  End-of-session handoff: commit remaining work, update progress, write handoff note for next session.
  Trigger: "handoff", "end session", "wrap up", "I'm done for now", "save state".
version: 0.1.0
---

# /foundry-handoff — Session Handoff

## What it does

Prepares a clean handoff for the next session. Commits work, updates progress, writes a handoff note.

## Steps

1. **Check for uncommitted changes** — `git status`. If dirty:
   - Run `/foundry-verify` — if passing, commit
   - If failing, note failures in handoff note

2. **Update progress** — ensure `foundry-progress.json` reflects current state:
   - All completed tasks marked done
   - Any new decisions recorded
   - Current phase accurate
   - Blockers noted

3. **Write handoff note** to `.foundry/handoff-note.md`:

```markdown
# Handoff Note — <date>

## Session Summary
<2-3 sentences: what was accomplished>

## Completed This Session
- <task 1>
- <task 2>

## In Progress
- <task>: <current state, what's left>

## Decisions Made
- <decision 1>: <why>

## Blockers
- <blocker>: <status>

## Next Steps
1. <immediate next action>
2. <follow-up>

## Context
- Key files touched: <list>
- Branch: <current branch>
- Last commit: <hash> <message>
```

4. **Commit handoff** — commit progress + handoff note: `chore: session handoff`

5. **Report** session summary to user.

## Important

- The handoff note is ephemeral — overwritten each session. Critical info goes in progress file.
- The next session's SessionStart hook reads this note and injects it as context.
- Keep the note concise — it needs to fit in ~500 tokens when injected.
