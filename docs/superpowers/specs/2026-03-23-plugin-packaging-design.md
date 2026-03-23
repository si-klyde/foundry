# MS-H0.11: Plugin Packaging Design

> **Date:** 2026-03-23
> **Status:** Draft
> **PRD ref:** `docs/foundry-harness-prd-v3.md` section 0.11

## Goal

Package Foundry L0 as a Claude Code plugin marketplace so it installs/uninstalls/updates via the plugin system instead of a manual `install.sh`.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Plugin location | Keep `packages/layer0/` | Avoids file moves, preserves packages convention for L1-L3 |
| Marketplace location | `.claude-plugin/marketplace.json` at repo root | Standard convention per Claude Code docs |
| Install method | `/plugin marketplace add` + `/plugin install` | Plugin system handles registration, caching, updates natively |
| Legacy cleanup | Standalone `migrate.sh` | One-time migration, separate from new install flow |
| `install.sh` | Deprecate, keep for reference | Add deprecation notice, point to plugin install |

## Repo Structure (changes only)

```
foundry/
├── .claude-plugin/
│   └── marketplace.json          ← NEW
├── packages/
│   └── layer0/
│       ├── .claude-plugin/
│       │   └── plugin.json       ← EXISTS (no changes)
│       ├── hooks/
│       │   └── hooks.json        ← EXISTS (no changes)
│       ├── migrate.sh            ← NEW (already written)
│       ├── install.sh            ← EXISTS (add deprecation notice)
│       └── ...                   ← all other dirs unchanged
```

## New File: `.claude-plugin/marketplace.json`

```json
{
  "name": "foundry",
  "owner": { "name": "Growgami", "email": "collide@growgami.com" },
  "metadata": {
    "description": "Agent orchestration layer: structured workflows, verification, progress tracking, cross-session continuity",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "foundry",
      "description": "Claude Code enhancement layer — hooks, skills, agents, rules for disciplined development workflows",
      "source": "./packages/layer0"
    }
  ]
}
```

## New File: `packages/layer0/migrate.sh`

Already written. Removes:
1. 15 copied skills from `~/.claude/skills/foundry-*`
2. 5 copied agents from `~/.claude/agents/foundry-*.md`
3. 4 `run-hook.cmd` hook entries from `settings.json` (preserves non-Foundry hooks)
4. Stale `foundry@foundry-local` from `enabledPlugins`
5. Context System block from global `CLAUDE.md`
6. Stale `foundry-local` plugin cache dir

Idempotent — safe to run on clean installs (reports "no legacy artifacts found").

## Modified File: `packages/layer0/install.sh`

Add deprecation notice at top (lines 2-5):

```bash
# DEPRECATED: Use the plugin system instead.
# Migration:  bash packages/layer0/migrate.sh
# Install:    /plugin marketplace add /path/to/foundry
#             /plugin install foundry@foundry
```

## Install Flow

### New users

```bash
# In Claude Code:
/plugin marketplace add /path/to/foundry    # local
/plugin marketplace add collide/foundry     # or GitHub

/plugin install foundry@foundry
```

### Existing users (legacy install.sh)

```bash
# Terminal:
bash packages/layer0/migrate.sh

# Then in Claude Code:
/plugin marketplace add /path/to/foundry
/plugin install foundry@foundry
```

### Local dev / testing

```bash
claude --plugin-dir /path/to/foundry/packages/layer0
```

## Plugin System Behavior

When installed via plugin system:
- `packages/layer0/` is **copied to** `~/.claude/plugins/cache/foundry/foundry/<version>/`
- Skills auto-discovered from `skills/*/SKILL.md`
- Agents auto-discovered from `agents/*.md`
- Hooks loaded from `hooks/hooks.json`
- `${CLAUDE_PLUGIN_ROOT}` resolves to the cached copy at runtime
- All files must be inside plugin root — no `../` references (already satisfied)

## What Stops Working

- `install.sh` direct install — deprecated, still functional but not recommended
- Manual hook entries in `settings.json` — replaced by `hooks.json` in plugin
- Skills/agents in `~/.claude/skills/` and `~/.claude/agents/` — replaced by plugin cache auto-discovery

## Validation

1. `claude plugin validate .` from repo root — checks marketplace.json + plugin structure
2. `/plugin install foundry@foundry` — verify hooks fire on session start
3. Check skills appear in `/help`
4. Verify hooks coexist with user hooks (bob gate, dirty tracking)

## Doc Updates (during implementation)

These surrounding docs must be updated to stay consistent:

1. **`decisions.md`** — revise "User-level install over plugin approach" ADR. The original issue was symlink pruning; the plugin marketplace system copies (not symlinks), making the plugin approach viable now.
2. **`progress.md`** — update install method description and add H0.11 completion status.
3. **PRD section 0.11** — update repo structure example to reflect `packages/layer0/` (not `plugins/foundry/`), update source path, note resolved questions.

## Notes

- `${CLAUDE_PLUGIN_ROOT}` is available as a **runtime environment variable** inside hook scripts (confirmed via Claude Code plugin-dev docs). The session-start hook already derives `PLUGIN_ROOT` from `SCRIPT_DIR/..` which also works — both paths resolve correctly in plugin cache.
- `using-foundry` skill will appear in `/help` via auto-discovery. Acceptable — it's harmless if invoked manually, and the SessionStart hook still injects it automatically.
- Hook scripts reference `../scripts/` (e.g., `garden-docs.sh`) — this is intra-plugin traversal, not escaping the plugin root. Works in cache.

## Out of Scope

- GitHub publishing (done separately after local validation)
- L1-L3 paths — unaffected, no changes needed
- `foundry.json` project config — unchanged
- Doc gardening setup (`garden-setup.sh`) — still per-project, separate from plugin install
