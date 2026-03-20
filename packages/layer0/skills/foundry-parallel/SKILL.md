---
name: foundry-parallel
description: >
  Set up git worktree for parallel work streams. Creates isolated working copy for independent tasks.
  Trigger: "parallel", "worktree", "work on two things", "independent task".
version: 0.1.0
---

# /foundry-parallel — Parallel Work via Git Worktrees

## What it does

Creates a git worktree for running independent work in parallel without conflicts.

## Arguments

- `$ARGUMENTS`: branch name or task description for the parallel work

## Steps

1. **Validate state:**
   - Ensure current work is committed or stashed
   - Ensure no existing worktree for same branch

2. **Create worktree:**
   ```bash
   git worktree add ../project-<branch> -b <branch>
   ```

3. **Copy Foundry state** to new worktree:
   - Copy `foundry.json`
   - Copy `foundry-progress.json`
   - Create `.foundry/` directory structure

4. **Report:**
   ```
   Worktree created: ../project-<branch>
   Branch: <branch>

   To work in it: cd ../project-<branch>
   To remove when done: git worktree remove ../project-<branch>
   ```

## Important

- Only for truly independent tasks — no shared file modifications
- Each worktree gets its own `.foundry/` state
- Merge back to main branch when parallel work is complete
- Clean up worktrees after merging: `git worktree prune`
