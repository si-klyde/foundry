# Plan: Cascading AGENTS.md + Doc Gardening

## Summary

Restructure CLAUDE.md from monolith → thin router. Distribute context into AGENTS.md files per directory. Add automated doc gardening via git hook that scans diffs and updates affected AGENTS.md files.

## Affected Files

| File | Action |
|---|---|
| `CLAUDE.md` | Rewrite → thin router, pointers only |
| `packages/layer0/AGENTS.md` | Create — L0 harness gotchas, patterns |
| `docs/AGENTS.md` | Create — doc organization, what's current vs legacy |
| `docs/decisions.md` | Create — ADRs extracted from PRDs + progress |
| `.claude/scripts/garden-docs.sh` | Create — doc gardening script |
| `.claude/settings.json` | Update — register gardening hook |

## What goes where

### CLAUDE.md (root)
- One-liner project description
- Directory map with → AGENTS.md pointers
- Verification commands (agent needs these everywhere)
- Nothing else

### packages/layer0/AGENTS.md
- Install method gotcha (plugin approach failed, user-level works)
- Hook coexistence rules (foundry hooks alongside user hooks)
- Hook script dependencies (python3 for JSON parsing)
- Skill naming convention
- Subagent invocation pattern
- Known limitations (scope guard file-level only, stop hook blocks)
- → decisions.md for architecture choices

### docs/AGENTS.md
- Which PRD is current (v3 supersedes v2)
- progress.md is source of truth for implementation state
- Plans go in docs/plans/
- Legacy: v2 PRD kept for bug reference, not active spec

### docs/decisions.md
- All LLM calls via `claude --print`, no Anthropic API (from v3 rewrite)
- No `any` types, strict mode always
- File-based state, no database (for L0-L2)
- User-level install over plugin approach
- External verification only, no semantic eval
- TDD: failing tests before implementation

## Doc Gardening

**Trigger:** Claude Code stop hook (runs on session end)

**How it works:**
1. Hook runs `git diff --cached --name-only` (or `git diff HEAD~1 --name-only` if post-commit)
2. Groups changed files by directory
3. For each directory with an AGENTS.md, checks if the diff introduces patterns/gotchas not yet documented
4. Outputs a suggestion to the agent (not auto-edit — human reviews)

**Why stop hook, not post-commit:**
- Runs inside the Claude Code session, so the agent can act on it
- Cheaper than spawning a new `claude --print` for gardening
- Agent already has context about what changed and why

**Alternative (cron):** A standalone script that runs periodically, diffs since last run, spawns `claude --print` to suggest AGENTS.md updates. More expensive but catches manual edits too.

## Implementation Steps

1. Create `docs/decisions.md` — extract ADRs from PRDs and progress
2. Create `packages/layer0/AGENTS.md` — extract gotchas/patterns from progress.md dogfood results
3. Create `docs/AGENTS.md` — doc organization context
4. Rewrite `CLAUDE.md` — strip to router
5. Create doc gardening script
6. Register gardening hook
7. Test: make a change in layer0, end session, verify gardening fires

## Risks

- Doc gardening in stop hook adds latency to session exit
- AGENTS.md files can rot if gardening doesn't run (manual edits outside Claude Code)
- Over-documenting: need discipline to keep AGENTS.md terse

## Decisions

- Gardening: cron script per project. Catches manual edits, runs outside sessions.
- Auto-edit AGENTS.md files directly, commit changes.
- Delete all legacy references (cli, spike, sdk). No "legacy" section.
- Package gardening in `packages/layer0/` so it installs to any workspace.
