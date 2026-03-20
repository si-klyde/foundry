# Plan: Foundry × Superpowers Integration

## Summary

Integrate Superpowers plugin (v5.0.2) with Foundry L0 so they complement rather than compete. Foundry owns infrastructure (hooks, state, context, gardening). Superpowers owns in-session discipline (planning, execution, debugging, verification). A bridge rule coordinates which system handles what.

## Problem

Both plugins fire in every session. Without coordination:
- Agent uses superpowers:writing-plans but doesn't update foundry progress
- Agent uses foundry-plan but misses superpowers' review loop and bite-sized steps
- Agent finishes work but doesn't know whether to use /foundry-checkpoint or superpowers:finishing-a-development-branch
- Debugging has no foundry skill — agent either uses superpowers:systematic-debugging or thrashes
- Verification happens twice in different ways (foundry PostToolUse hooks + superpowers verification-before-completion) but they're not aware of each other

## Ownership Map

| Concern | Owner | Skill/Hook |
|---|---|---|
| **Planning** | Superpowers | writing-plans (format, review loop, checkboxes) |
| **Plan location + progress** | Foundry | foundry-progress, progress.md, docs/plans/ |
| **Execution** | Superpowers | subagent-driven-development / executing-plans |
| **Reactive verification** | Foundry | PostToolUse hooks (typecheck, quality gates) |
| **Completion gate** | Superpowers | verification-before-completion |
| **Debugging** | Superpowers | systematic-debugging |
| **TDD** | Superpowers | test-driven-development |
| **Parallel dispatch** | Superpowers | dispatching-parallel-agents |
| **Branch finishing** | Superpowers | finishing-a-development-branch |
| **Code review** | Superpowers | requesting-code-review / receiving-code-review |
| **Scope guard** | Foundry | PreToolUse hook |
| **Session handoff** | Foundry | foundry-handoff, Stop hook |
| **Context bridging** | Foundry | foundry-context, foundry-codemap, foundry-compact |
| **Doc gardening** | Foundry | garden-docs.sh, AGENTS.md |
| **Project config** | Foundry | foundry.json |
| **Brainstorming** | Superpowers | brainstorming |

## What Changes

### 1. New bridge rule: `rules/integration.md`

Injected via SessionStart alongside existing 6 rules. Tells the agent:
- Use superpowers skills for: planning, execution, debugging, TDD, verification, code review, branch finishing
- Use foundry skills for: progress tracking, context loading, codemap, handoff, checkpoint, doc scaffolding
- After superpowers:writing-plans completes → update foundry progress + save plan to docs/plans/
- After superpowers:finishing-a-development-branch → run /foundry-handoff
- When debugging → use superpowers:systematic-debugging (foundry has nothing)
- Foundry hooks fire automatically regardless — no coordination needed

### 2. Update foundry-plan skill

Currently a full planning skill. Change to a thin wrapper:
1. Invoke superpowers:writing-plans for plan creation
2. Save plan to `docs/plans/<slug>.md` (foundry convention)
3. Update foundry-progress.json with plan reference
4. Register plan scope with scope guard

### 3. Update foundry-checkpoint skill

Currently: verify → commit → update progress → update codemap.
Add: invoke superpowers:verification-before-completion gate before commit.

### 4. Update foundry-review skill

Currently invokes foundry-reviewer subagent.
Add: also invoke superpowers:requesting-code-review for the two-stage review (spec compliance + quality).

### 5. Retire overlapping foundry skills (or mark as fallbacks)

These foundry skills are weaker versions of superpowers equivalents:
- `foundry-plan` → becomes wrapper around superpowers:writing-plans
- `foundry-review` → enhanced with superpowers review pipeline
- `foundry-verify` → kept as-is (external pipeline), superpowers handles the "prove it" gate

### 6. Update SessionStart hook

Detect whether superpowers plugin is installed. If yes, inject `integration.md` rule. If no, foundry skills work standalone (no superpowers dependency).

### 7. Update global CLAUDE.md

Add integration awareness to Context System section so agent knows the coordination model.

## What Doesn't Change

- Foundry hooks (all 4) — fire automatically, no coordination needed
- Foundry scripts (garden-docs, garden-setup, etc.)
- Foundry subagents (planner, verifier, reviewer, context-builder, refactorer) — still available, superpowers subagent-driven-dev may use its own
- Doc gardening — superpowers has nothing here
- foundry.json config — unchanged
- Superpowers plugin files — we don't modify superpowers, only foundry

## Affected Files

| File | Action |
|---|---|
| `packages/layer0/rules/integration.md` | Create — bridge rule |
| `packages/layer0/skills/foundry-plan/SKILL.md` | Update — wrapper around superpowers |
| `packages/layer0/skills/foundry-checkpoint/SKILL.md` | Update — add verification gate |
| `packages/layer0/skills/foundry-review/SKILL.md` | Update — add two-stage review |
| `packages/layer0/hooks/session-start` | Update — detect superpowers, inject integration rule |
| `~/.claude/CLAUDE.md` | Update — integration awareness |
| `docs/decisions.md` | Update — add integration decision |
| `docs/progress.md` | Update — track this work |

## Implementation Steps

1. Write `rules/integration.md` — the bridge rule (~200 tokens)
2. Update session-start hook — detect superpowers, conditionally inject
3. Update foundry-plan SKILL.md — thin wrapper
4. Update foundry-checkpoint SKILL.md — add verification gate
5. Update foundry-review SKILL.md — two-stage review
6. Update global CLAUDE.md — integration section
7. Update decisions.md — record the integration decision
8. Reinstall foundry (bash install.sh)
9. Test: open a project, verify both systems coordinate

## Risks

- **Token budget**: integration.md + 6 existing rules must stay under 2K tokens. Currently at ~950. Budget: ~250 tokens for integration rule.
- **Superpowers updates**: we don't control superpowers. If skill names/behavior change, integration.md breaks. Mitigate: version-pin awareness, fallback to standalone foundry.
- **Skill invocation overhead**: agent now loads both foundry AND superpowers skills. More context consumed per session.
- **Circular delegation**: foundry-plan invokes superpowers:writing-plans which might reference superpowers:subagent-driven-development. Need to ensure no loops.

## Decisions

- foundry-plan tells user to install superpowers if not detected. No standalone fallback planning logic.
- Always-on when superpowers detected. No foundry.json toggle.
- Superpowers uses its own plan location (`docs/superpowers/plans/`). Foundry progress tracks the path wherever it is.
