---
name: foundry-clean
description: >
  Invoke the refactorer subagent for a cleanup pass. Removes console.log, debugger, unused code,
  fixes quality issues. Trigger: "clean up", "cleanup", "remove debug", "quality pass".
version: 0.1.0
---

# /foundry-clean — Cleanup via Subagent

## What it does

Delegates cleanup to the `foundry-refactorer` agent. The refactorer fixes quality issues and verifies after changes.

## Steps

1. **Identify target files:**
   - If args provided: use specified files
   - Otherwise: get changed files from `git diff --name-only`

2. **Launch refactorer agent** with:
   - Target file list
   - Verification commands from `foundry.json`
   - Quality criteria (no console.log, no debugger, no any, no dead code)

3. **Report results:**
   - What was cleaned up
   - Verification pass/fail after cleanup

## Arguments

- No args: clean all changed files
- `$ARGUMENTS`: specific files or directories to clean

## Important

- Run AFTER implementation, BEFORE checkpoint
- The refactorer runs verification after changes — if it breaks, it reverts
- Don't use for refactoring logic — only quality/style cleanup
