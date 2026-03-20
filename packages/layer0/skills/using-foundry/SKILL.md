---
name: using-foundry
description: >
  Bootstrap skill loaded at session start. Teaches the agent about Foundry's available skills,
  when to use them, and the expected development workflow. This skill auto-loads — do not invoke manually.
version: 0.1.0
---

# Foundry — Agent Orchestration Layer

You have access to the Foundry plugin. It provides structured workflows, verification, progress tracking, and cross-session continuity.

## Available Skills

| Skill | When to use |
|-------|-------------|
| `/foundry-init` | First time in a project — creates `.foundry/` dirs + `foundry.json` |
| `/foundry-plan` | Before non-trivial implementation — structured planning workflow |
| `/foundry-verify` | Run project verification (typecheck, lint, test) and report results |
| `/foundry-progress` | Read/update `foundry-progress.json` — track tasks, decisions, blockers |
| `/foundry-checkpoint` | After meaningful progress — atomic verify + commit + progress update |
| `/foundry-handoff` | End of session — commit + progress + write handoff note for next session |
| `/foundry-status` | Quick overview — plan progress, changed files, recent decisions |
| `/foundry-codemap` | Generate `.foundry/codemap.md` — project structure + exports + recent activity |
| `/foundry-context` | Smart context loading — codemap, imports, progress, git log |
| `/foundry-learn` | Extract reusable patterns to `.foundry/learned/` |
| `/foundry-compact` | Strategic compaction — save context before compacting at phase boundaries |
| `/foundry-parallel` | Set up git worktree for parallel work |
| `/foundry-benchmark` | A/B compare sessions with/without Foundry |
| `/foundry-review` | Invoke reviewer subagent against criteria |
| `/foundry-clean` | Invoke refactorer subagent for cleanup pass |

## Core Workflow

```
Start session → read progress → /foundry-plan (if new work)
  → implement (TDD) → /foundry-checkpoint (repeat)
  → /foundry-handoff (end session)
```

## Key Behaviors

1. **Always read `foundry-progress.json` at session start** — it's the source of truth for what's done, in-progress, and blocked.
2. **Plan before coding** — use `/foundry-plan` for anything beyond trivial fixes. Plans live in `.foundry/plans/`.
3. **Checkpoint often** — `/foundry-checkpoint` does verify + commit + progress update atomically. Use after each logical unit of work.
4. **Handoff at end** — `/foundry-handoff` writes `.foundry/handoff-note.md` with session summary, decisions, and next steps for the next session.
5. **Verification is external** — typecheck/lint/test results are the only pass/fail signal. Self-assessment is insufficient.

## Project State Files

| File | Purpose |
|------|---------|
| `foundry.json` | Project config — verification commands, thresholds, feature flags |
| `foundry-progress.json` | Task tracking — status, decisions, blockers, completed items |
| `.foundry/plans/` | Plan documents (markdown + structured data) |
| `.foundry/active-plan.json` | Currently executing plan pointer + current task |
| `.foundry/handoff-note.md` | Session-end summary for cross-session continuity |
| `.foundry/codemap.md` | Project structure overview (generated) |
| `.foundry/session-log.jsonl` | Tool call log for current session |
| `.foundry/learned/` | Reusable patterns extracted via `/foundry-learn` |
