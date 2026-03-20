# docs/

## What's current
- `foundry-harness-prd-v3.md` — active spec. Supersedes v2.
- `progress.md` — source of truth for implementation state. Update after completing work.
- `decisions.md` — ADRs. Check before proposing architectural changes.
- `plans/` — implementation plans per feature.

## What's legacy
- `foundry-harness-prd-v2.md` — kept for bug reference only. v2's 4-layer external wrapper failed in integration testing ($1.94 wasted, 3/8 tasks passed). Do not implement from this.
- `workspace-prd.md` — original grand vision (daemon, web UI, TUI). Still directionally valid but L0 is the only active milestone.

## Gotchas
- PRD v3 says "L1/L2 core done, bugs identified" in the implementation table — this is stale. No CLI code exists. Only L0 is implemented.
- Progress.md tracks against v3 PRD but the "Next Steps" section may be outdated between sessions. Always read it fresh.
