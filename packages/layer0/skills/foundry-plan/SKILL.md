---
name: foundry-plan
description: >
  Use before non-trivial implementation. Delegates to superpowers:writing-plans for plan creation,
  then registers with foundry progress tracking. Trigger: "plan", "let's plan", "design this".
version: 0.2.0
---

# /foundry-plan — Structured Planning Workflow

## What it does

Coordinates planning between Superpowers and Foundry. Superpowers writes the plan. Foundry tracks it.

## Requires

**Superpowers plugin must be installed.** If not detected, tell the user:
> Foundry delegates planning to the Superpowers plugin. Install it from the Claude Code marketplace:
> `claude plugins install superpowers`

## Workflow

### 1. Delegate to Superpowers

Invoke `superpowers:writing-plans`. Let it handle:
- Scope check and subsystem decomposition
- File structure mapping
- Bite-sized task breakdown with checkboxes
- Plan review loop via subagent
- Plan saves to `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`

### 2. Register with Foundry

After superpowers completes the plan:

**Set as active plan** — write `.foundry/active-plan.json`:
```json
{
  "plan_file": "docs/superpowers/plans/<filename>.md",
  "status": "approved",
  "current_task": null,
  "created": "<ISO>",
  "updated": "<ISO>"
}
```

**Update progress** — run `/foundry-progress` to register the plan in `foundry-progress.json`.

**Register scope** — extract file paths from the plan's task `Files:` sections for the scope guard.

### 3. Hand off to execution

Superpowers decides the execution path:
- With subagents → `superpowers:subagent-driven-development`
- Without subagents → `superpowers:executing-plans`

Use `/foundry-checkpoint` between tasks for atomic save points.

### Subcommands

- **`/foundry-plan list`** — list all plans in `.foundry/plans/` and `docs/superpowers/plans/` with status
- **`/foundry-plan show <slug>`** — display plan details
- **`/foundry-plan cancel`** — mark active plan as cancelled, clear active-plan.json

## Important

- Plans are the source of truth during implementation
- Update `active-plan.json` `current_task` as you move between tasks
- Use `/foundry-checkpoint` after each completed task, not just at the end
