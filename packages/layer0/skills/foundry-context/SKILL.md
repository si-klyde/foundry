---
name: foundry-context
description: >
  Smart context loading for unfamiliar code areas. Loads codemap, traces imports, reads progress,
  checks git log. Trigger: "load context", "context for <area>", "I need to understand <module>".
version: 0.1.0
---

# /foundry-context — Smart Context Loading

## What it does

Systematically loads context for a code area, avoiding the common mistake of diving in without orientation.

## Arguments

- `$ARGUMENTS`: optional area/module/file to focus on (e.g., "auth", "src/api/", "database layer")

## Steps

1. **Read codemap** — if `.foundry/codemap.md` exists, read it. If not, suggest `/foundry-codemap` first.

2. **Read progress** — read `foundry-progress.json` for current state, recent decisions, blockers.

3. **Read handoff note** — if `.foundry/handoff-note.md` exists, read for previous session context.

4. **Focused exploration** (if area specified):
   a. Find relevant files via `Glob` matching the area
   b. Read key files (entry points, types, interfaces)
   c. Trace imports to understand dependencies
   d. Check `git log --oneline -5 -- <files>` for recent changes

5. **Git context:**
   ```bash
   git log --oneline -10
   git branch -a
   ```

6. **Summarize** what was learned:
   - Key files and their roles
   - Data flow through the area
   - Recent changes and their purpose
   - Any decisions from progress file that affect this area

## Important

- Read before writing — always use this skill before modifying unfamiliar code
- Don't read every file — focus on interfaces, types, and entry points first
- Note any gaps in understanding as questions for the user
