# packages/layer0/

Claude Code enhancement layer. Pure files — no build, no runtime deps.

## Install
`bash install.sh` copies skills → `~/.claude/skills/`, agents → `~/.claude/agents/`, hooks → `settings.json`.

## Gotchas
- Plugin approach (symlink to `~/.claude/plugins/cache/`) failed — Claude Code prunes symlinks. User-level install is the only path that works.
- Hook scripts depend on `python3` for JSON parsing. Falls back gracefully but hooks degrade without it.
- `grep -c` exits 1 on zero matches. Never use `|| true` after — it eats the exit code. Use `|| VAR=0` instead.
- Stop hook blocks session exit when quality issues found. May annoy users. Configurable blocking is a known TODO.
- Scope guard is file-level only. Cannot detect feature creep within files already in the plan.
- Delegation rule (~150 tokens) always injected even when `features.delegation` disabled. Waste of context.

## Patterns
- Hooks coexist with user hooks by using different matchers. Foundry PostToolUse matches `Write|Edit`, user's matches `Bash`.
- SessionStart injects rules + progress + handoff + active plan. ~950 tokens for rules, variable for the rest.
- Skills are invocable via `/foundry-*`. Bootstrap skill `using-foundry` is injected by SessionStart, never invoked directly.
- Subagents in `agents/` are spawned by Claude Code's Agent tool with `subagent_type` parameter.
- Scripts in `scripts/` are called by hooks, not directly by the agent.

## Structure
- `hooks/` — 4 lifecycle hooks (session-start, post-tool-use, pre-tool-use, stop)
- `rules/` — 6 injected rules (~950 tokens total)
- `skills/` — 15 invocable + 1 bootstrap
- `agents/` — 5 subagent definitions
- `scripts/` — 3 helper scripts called by hooks
- `templates/` — foundry.json template for `/foundry-init`

→ [decisions.md](../../docs/decisions.md) for architecture choices
