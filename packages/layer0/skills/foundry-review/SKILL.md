---
name: foundry-review
description: >
  Code review via subagent. Uses superpowers two-stage review (spec + quality) when available,
  falls back to foundry-reviewer agent. Trigger: "review", "review changes", "pre-checkpoint review".
version: 0.2.0
---

# /foundry-review — Code Review

## What it does

Reviews code changes against plan criteria. When Superpowers is installed, uses its two-stage review pipeline (spec compliance → code quality). Otherwise falls back to the foundry-reviewer agent.

## Steps (with Superpowers)

1. **Check prerequisites:**
   - Active plan exists (`.foundry/active-plan.json`)
   - There are uncommitted changes to review (`git status`)

2. **Stage 1: Spec compliance review**
   Use the spec-reviewer approach from `superpowers:subagent-driven-development`. Launch a reviewer subagent that checks: does the code match what the plan specified? Nothing missing, nothing extra.

3. **Stage 2: Code quality review**
   After spec compliance passes, launch a quality reviewer subagent. Checks: is the implementation well-built? DRY, YAGNI, KISS, no anti-patterns.

4. **If issues found:** report them. Implementer fixes. Re-review.

5. **If both stages pass:** proceed to `/foundry-checkpoint`.

## Steps (without Superpowers)

1. **Check prerequisites** — same as above.

2. **Launch foundry-reviewer agent** with context:
   - Active plan file path
   - Current task from active-plan.json
   - Changed files list

3. **Report results:**
   - REJECT: list blocking issues
   - NEEDS WORK: list advisory issues
   - APPROVE: proceed to checkpoint

## Arguments

- No args: review all uncommitted changes against active plan
- `$ARGUMENTS`: specific files or criteria to review against

## Important

- Review BEFORE checkpoint, not after
- Spec compliance comes before code quality — wrong order wastes time
- If no active plan, review against general quality criteria only
