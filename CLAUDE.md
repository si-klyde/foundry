# Foundry

Personal dev workspace + agent harness.

## Where to look

| Path | What | Context |
|---|---|---|
| `packages/layer0/` | Claude Code plugin (hooks, skills, agents, rules) | → [AGENTS.md](packages/layer0/AGENTS.md) |
| `docs/` | PRDs, plans, progress | → [AGENTS.md](docs/AGENTS.md) |
| `docs/decisions.md` | Architecture decisions (ADRs) | Check before proposing changes |
| `docs/progress.md` | Implementation state | Update after completing work |

## Verify

```
pnpm typecheck && pnpm test && pnpm build
```

## Conventions

- TDD: failing test → implement
- No `any` — use `unknown` + narrowing
- Comments only for non-obvious logic
- All LLM calls via `claude --print`, never Anthropic API
