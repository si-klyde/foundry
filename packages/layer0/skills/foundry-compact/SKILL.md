---
name: foundry-compact
description: >
  Strategic compaction at phase boundaries. Saves critical context before Claude Code compacts
  the conversation. Trigger: "compact", "save context and compact", "phase boundary", context is getting long.
version: 0.1.0
---

# /foundry-compact — Strategic Compaction

## What it does

Prepares for conversation compaction by saving critical context that would otherwise be lost.

## When to Use

- At phase boundaries (finishing one plan task, starting next)
- When context window is getting full (many tool calls, large file reads)
- Before switching to a different area of the codebase
- When prompted by Foundry's change counter reminder

## Steps

1. **Save current state to progress:**
   - Update `foundry-progress.json` with current task status
   - Record any in-flight decisions
   - Note current working state (branch, uncommitted changes)

2. **Update active plan** (if exists):
   - Mark completed tasks
   - Update `current_task` in `.foundry/active-plan.json`

3. **Write compaction note** to `.foundry/handoff-note.md`:
   - What was accomplished since last checkpoint
   - Current task and its state
   - Key decisions made
   - Immediate next step

4. **Regenerate codemap** (if structural changes were made):
   - Run `/foundry-codemap` to update `.foundry/codemap.md`

5. **Report readiness:**
   ```
   Context saved. Safe to compact.
   - Progress: updated (5/12 tasks)
   - Plan: task 3 in-progress
   - Handoff note: written
   - Next step: <immediate next action>
   ```

6. **Let Claude Code compact** — the SessionStart hook will re-inject rules + progress + handoff note after compaction.

## Important

- NEVER compact mid-task — always reach a clean stopping point first
- The handoff note + progress file are what survive compaction
- After compaction, re-read context via `/foundry-context` if needed
