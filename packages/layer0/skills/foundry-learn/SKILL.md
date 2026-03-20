---
name: foundry-learn
description: >
  Extract reusable patterns and lessons to .foundry/learned/ for future sessions.
  Trigger: "learn this", "save this pattern", "remember this approach", "extract lesson".
version: 0.1.0
---

# /foundry-learn — Extract Reusable Patterns

## What it does

Captures patterns, lessons learned, and reusable approaches in `.foundry/learned/` for future reference.

## Arguments

- `$ARGUMENTS`: optional description of what to learn (e.g., "auth pattern", "error handling approach")

## Steps

1. **Identify the pattern.** From recent work or user description, extract:
   - What was the problem?
   - What approach worked (or didn't)?
   - What's the reusable pattern?

2. **Write to `.foundry/learned/<slug>.md`:**
   ```markdown
   # <Pattern Name>
   Date: <ISO date>
   Tags: <comma-separated>

   ## Problem
   <What situation triggers this pattern>

   ## Solution
   <The approach, with code snippets if relevant>

   ## Why
   <Why this works, what alternatives were considered>

   ## Example
   <Concrete example from current project>
   ```

3. **Report** what was saved.

## When to Use

- After solving a tricky bug — save the debugging approach
- After a successful refactor — save the pattern
- When a user corrects your approach — save the lesson
- After discovering a project-specific convention — save it

## Important

- Keep entries concise — 50-100 lines max
- Use concrete examples, not abstract descriptions
- Tag entries for searchability
- Don't duplicate what's in CLAUDE.md — learned/ is for project-specific patterns
