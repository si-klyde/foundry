# Foundry — Claude Code Enhancement Layer

Agent orchestration plugin for Claude Code. Adds structured workflows, continuous verification, progress tracking, and cross-session continuity.

## Install

```bash
# In Claude Code:
/plugin marketplace add si-klyde/foundry
/plugin install foundry@foundry
```

Migrating from legacy `install.sh`? Run `bash packages/layer0/migrate.sh` first.

## What You Get

**Hooks** — automatic behaviors:
- **SessionStart** — injects rules, progress state, handoff notes
- **PostToolUse** — typecheck on .ts edits, quality gates, session logging
- **PreToolUse** — scope enforcement against active plan
- **Stop** — session audit, auto-handoff note, desktop notification

**Skills** — invoke via `/skill-name`:
- `/foundry-init` — initialize Foundry in a project
- `/foundry-plan` — structured planning workflow
- `/foundry-verify` — run verification pipeline
- `/foundry-progress` — track tasks, decisions, blockers
- `/foundry-checkpoint` — atomic verify + commit + progress update
- `/foundry-handoff` — end-of-session handoff
- `/foundry-status` — project status overview
- `/foundry-codemap` — generate project structure map
- `/foundry-context` — smart context loading
- `/foundry-learn` — extract reusable patterns
- `/foundry-compact` — strategic compaction
- `/foundry-parallel` — git worktree for parallel work
- `/foundry-benchmark` — session effectiveness metrics
- `/foundry-review` — code review via subagent
- `/foundry-clean` — cleanup via subagent

**Agents** — delegated specialists:
- `foundry-planner` — read-only planning
- `foundry-verifier` — run checks only
- `foundry-reviewer` — code review
- `foundry-context-builder` — context summaries
- `foundry-refactorer` — cleanup with write access

## Core Workflow

```
Start session → read progress → /foundry-plan
  → implement (TDD) → /foundry-checkpoint (repeat)
  → /foundry-handoff (end session)
```

## Project Files

| File | Committed? | Purpose |
|------|-----------|---------|
| `foundry.json` | Yes | Project config |
| `foundry-progress.json` | Yes | Task/decision tracking |
| `.foundry/plans/` | Yes | Plan documents |
| `.foundry/codemap.md` | Yes | Project structure |
| `.foundry/learned/` | Yes | Reusable patterns |
| `.foundry/active-plan.json` | No | Current plan pointer |
| `.foundry/handoff-note.md` | No | Session handoff |
| `.foundry/session-log.jsonl` | No | Ephemeral session log |

## Uninstall

```bash
# In Claude Code:
/plugin remove foundry@foundry
```

## Coexistence

Foundry hooks coexist with existing user hooks:
- **Bob gate** (PreToolUse on Bash) — different matcher, no conflict
- **Dirty tracking** (PostToolUse on Write|Edit) — same matcher, different concerns
- **Session context** (SessionStart) — both inject additionalContext, content merges
- **Last-session** (Stop) — writes different file, no conflict
