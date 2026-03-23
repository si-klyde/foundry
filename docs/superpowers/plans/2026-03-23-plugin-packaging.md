# Plugin Packaging (MS-H0.11) Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package Foundry L0 as a Claude Code plugin marketplace so it installs via the plugin system instead of `install.sh`.

**Architecture:** Add `.claude-plugin/marketplace.json` at repo root pointing to `packages/layer0/` as the plugin source. Deprecate `install.sh`. Migration script (already written) cleans legacy artifacts.

**Tech Stack:** JSON, Bash, Markdown

**Spec:** `docs/superpowers/specs/2026-03-23-plugin-packaging-design.md`

---

## Chunk 1: Core Implementation

### Task 1: Create marketplace.json

**Files:**
- Create: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create the marketplace manifest**

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

- [ ] **Step 2: Validate**

Run: `claude plugin validate .` from repo root
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat(plugin): add marketplace.json for plugin packaging"
```

---

### Task 2: Deprecate install.sh

**Files:**
- Modify: `packages/layer0/install.sh:1-4`

- [ ] **Step 1: Add deprecation notice after shebang**

Insert after line 1:

```bash
# DEPRECATED: Use the plugin system instead.
# Migration:  bash packages/layer0/migrate.sh
# Install:    /plugin marketplace add /path/to/foundry
#             /plugin install foundry@foundry
```

- [ ] **Step 2: Commit**

```bash
git add packages/layer0/install.sh
git commit -m "chore: deprecate install.sh in favor of plugin system"
```

---

## Chunk 2: Doc Updates

### Task 3: Update decisions.md

**Files:**
- Modify: `docs/decisions.md`

- [ ] **Step 1: Revise the install ADR**

Replace the "User-level install over plugin approach" entry with:

```markdown
## Plugin marketplace over user-level install
Original approach (user-level install via `install.sh`) copied skills/agents to `~/.claude/` and injected hooks into `settings.json`. This worked but was fragile, non-portable, and inconsistent with how other plugins are distributed. The original plugin attempt failed because Claude Code pruned symlinks — but the marketplace system copies plugin dirs to cache (no symlinks), resolving the issue. `hooks.json` + `${CLAUDE_PLUGIN_ROOT}` handle hook registration portably. Migration script cleans legacy artifacts.
```

- [ ] **Step 2: Commit**

```bash
git add docs/decisions.md
git commit -m "docs: update install ADR — plugin marketplace over user-level"
```

---

### Task 4: Update progress.md

**Files:**
- Modify: `docs/progress.md`

- [ ] **Step 1: Update current state description**

Change the install method line (around line 12) from:
```
Install method: `bash packages/layer0/install.sh` copies skills/agents to `~/.claude/`, registers hooks in `settings.json`. No plugin system — direct user-level install.
```
to:
```
Install method: Plugin marketplace. `/plugin marketplace add /path/to/foundry` + `/plugin install foundry@foundry`. Legacy `install.sh` deprecated; `migrate.sh` cleans old artifacts.
```

- [ ] **Step 2: Add H0.11 section**

After the "Cascading AGENTS.md + Doc Gardening" section, add:

```markdown
## Plugin Packaging (2026-03-23)

Packaged Foundry as a Claude Code plugin marketplace (`foundry@foundry`).

| What changed | Detail |
|---|---|
| `.claude-plugin/marketplace.json` | Repo-root marketplace pointing to `./packages/layer0` |
| `migrate.sh` | One-time cleanup of legacy install.sh artifacts |
| `install.sh` | Deprecated — kept for reference |
| Install flow | `/plugin marketplace add` + `/plugin install` |
| `decisions.md` | Revised install ADR |
```

- [ ] **Step 3: Update Next Steps**

Remove "MS-H0.11 — Plugin packaging" from the next steps list if present. Update item 6 from "MS-H1 planning — session wrapper CLI" to reflect it's the next milestone.

- [ ] **Step 4: Commit**

```bash
git add docs/progress.md
git commit -m "docs: update progress for H0.11 plugin packaging"
```

---

### Task 5: Update PRD section 0.11

**Files:**
- Modify: `docs/foundry-harness-prd-v3.md`

- [ ] **Step 1: Update resolved questions**

In section 0.11, under "Unresolved:", change to "Resolved:" and update:

```markdown
**Resolved:**
- `install.sh` is deprecated. Users run `/plugin marketplace add` + `/plugin install`. `migrate.sh` cleans legacy artifacts.
- L1-L3 live outside the plugin at `packages/layer0/` (no move to `plugins/foundry/`). Repo structure unchanged except for `.claude-plugin/marketplace.json` at root.
```

- [ ] **Step 2: Update implementation status table**

Change H0.11 status from "Not started" to "Done".

- [ ] **Step 3: Commit**

```bash
git add docs/foundry-harness-prd-v3.md
git commit -m "docs: update PRD H0.11 — resolved questions, mark done"
```

---

## Chunk 3: Validation

### Task 6: End-to-end validation

- [ ] **Step 1: Run plugin validator**

Run: `claude plugin validate .` from repo root
Expected: No errors for marketplace.json and plugin structure

- [ ] **Step 2: Test local install**

In Claude Code:
```
/plugin marketplace add /path/to/foundry
/plugin install foundry@foundry
```
Expected: Plugin installs, skills appear in `/help`

- [ ] **Step 3: Verify hooks fire**

Start a new Claude Code session in a project with `foundry.json`.
Expected: SessionStart hook injects rules + progress context

- [ ] **Step 4: Verify coexistence**

Check that user hooks (bob gate, dirty tracking, last-session) still fire alongside Foundry plugin hooks.
