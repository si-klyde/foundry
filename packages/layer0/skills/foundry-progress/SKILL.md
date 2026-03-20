---
name: foundry-progress
description: >
  Read or update foundry-progress.json — the cross-session source of truth for tasks, decisions, and blockers.
  Trigger: "update progress", "mark done", "add decision", "what's the status?", "progress".
version: 0.1.0
---

# /foundry-progress — Progress Tracking

## What it does

CRUD operations on `foundry-progress.json`. This file persists across sessions and is the primary mechanism for cross-session continuity.

## Schema

```json
{
  "version": "0.1.0",
  "project": "project-name",
  "last_updated": "2026-03-17T12:00:00Z",
  "current_phase": "Phase 2: Core Skills",
  "tasks": [
    {
      "id": "t1",
      "title": "Implement auth middleware",
      "status": "completed|in-progress|blocked|pending",
      "completed_at": "2026-03-17T12:00:00Z",
      "notes": "Used express-jwt"
    }
  ],
  "decisions": [
    {
      "id": "d1",
      "date": "2026-03-17",
      "decision": "Use JWT over session cookies",
      "reason": "Stateless, works with mobile clients"
    }
  ],
  "blockers": [
    {
      "id": "b1",
      "description": "API rate limit unclear",
      "status": "open|resolved",
      "resolution": ""
    }
  ]
}
```

## Subcommands

- **`/foundry-progress`** (no args) — read and display current progress summary
- **`/foundry-progress task <title>`** — add new task (status: pending)
- **`/foundry-progress done <id>`** — mark task completed with timestamp
- **`/foundry-progress block <id> <reason>`** — mark task blocked
- **`/foundry-progress decide <decision> -- <reason>`** — record a decision
- **`/foundry-progress blocker <description>`** — add a blocker
- **`/foundry-progress resolve <blocker-id> <resolution>`** — resolve a blocker
- **`/foundry-progress phase <name>`** — update current phase

## Important

- Always update `last_updated` timestamp on any write
- Keep task titles concise — details go in `notes`
- Decisions are append-only — never delete a decision, it's the audit trail
- Read this file at session start before doing any work
