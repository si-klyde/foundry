# Decisions

## All LLM calls via `claude --print`
No Anthropic API, no `ANTHROPIC_API_KEY`. Learned from v2 integration test — wrapping Claude Code as dumb subprocess created harness-around-a-harness. `--json-schema` for structured output, `--continue` for session continuity.

## No semantic evaluation
Running a full Claude Code session to eval a diff is absurdly expensive without direct Haiku API access. External verification (lint/test/typecheck) is the sole pass/fail signal.

## User-level install over plugin approach
Claude Code kept pruning symlinked plugins. Copying skills to `~/.claude/skills/`, agents to `~/.claude/agents/`, hooks to `settings.json` works reliably.

## File-based state, no database (L0-L2)
`.foundry/plans/`, `.foundry/executions/`, `foundry-progress.json`. SQLite only enters at L3 (Rust daemon).

## Strict TypeScript, no `any`
`unknown` + narrowing. Strict mode always.

## TDD: failing tests before implementation
Write the test, watch it fail, then implement.

## External verification is non-negotiable
Agent's opinion about whether code works is irrelevant. Lint/test/typecheck decide.

## Cascading AGENTS.md over monolith CLAUDE.md
CLAUDE.md is a thin router. Context lives in AGENTS.md per directory. No code snippets, no architecture explanations — gotchas, patterns, and pointers to decisions.md.

## Doc gardening via three triggers
Post-commit git hook (immediate), Stop hook (session sweep), cron (opt-in periodic). All call the same `garden-docs.sh`. Lock file prevents overlap. Packaged in L0 for reuse across workspaces.

## Delegate to Superpowers, don't duplicate
Superpowers plugin is stronger at in-session discipline (planning, execution, debugging, TDD, verification, code review). Foundry is stronger at infrastructure (hooks, state, context, gardening). Instead of duplicating superpowers' skills in foundry, foundry delegates to superpowers when detected and handles its own domain. Foundry skills that overlap become thin wrappers. When superpowers isn't installed, foundry works standalone.
