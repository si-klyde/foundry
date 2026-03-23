# Foundry Progress

> Last updated: 2026-03-18
> Tracking against: `docs/foundry-harness-prd-v3.md`

---

## Current State

**MS-H0 (Claude Code Enhancement Layer) — implemented, installed, dogfooded.**

Install method: Plugin marketplace. `/plugin marketplace add /path/to/foundry` + `/plugin install foundry@foundry`. Legacy `install.sh` deprecated; `migrate.sh` cleans old artifacts.

---

## MS-H0: Layer 0 — Claude Code Plugin

### Installation

| Item | Status | Target |
|------|--------|--------|
| Install script (+ uninstall) | Done | `install.sh` |
| Skills (16) | Installed | `~/.claude/skills/foundry-*` |
| Agents (5) | Installed | `~/.claude/agents/foundry-*.md` |
| Hooks (4) | Registered | `~/.claude/settings.json` (alongside user hooks) |
| Hook scripts | Source | `packages/layer0/hooks/*` (referenced by absolute path) |

### Hooks (4/4)

| Hook | Matcher | Coexists with |
|------|---------|---------------|
| SessionStart `*` | Inject rules + progress + handoff | User session-start.mjs (arch + last-session) |
| PostToolUse `Write\|Edit` | Typecheck, quality gates, logging | User post-tool-use.mjs (dirty tracking) |
| PreToolUse `Write\|Edit` | Scope guard, .md creation warning | User pre-tool-use.mjs on `Bash` (bob gate) — different matcher |
| Stop `*` | Session audit, auto-handoff, doc gardening, notify | User stop.mjs (last-session.md) |

### Rules (7)

Injected via SessionStart hook. ~1.1K tokens total (under 2K target).

workflow.md, scope.md, quality.md, context.md, git.md, delegation.md, integration.md

`integration.md` only injected when Superpowers plugin detected. SessionStart hook checks for `~/.claude/plugins/cache/claude-plugins-official/superpowers`.

### Skills (15 + 1 bootstrap)

| Skill | Category |
|-------|----------|
| using-foundry | Bootstrap (injected via SessionStart, not invocable) |
| foundry-init | Core |
| foundry-plan | Core |
| foundry-verify | Core |
| foundry-progress | Core |
| foundry-checkpoint | Core |
| foundry-handoff | Core |
| foundry-status | Core |
| foundry-codemap | Cross-session |
| foundry-context | Cross-session |
| foundry-learn | Cross-session |
| foundry-compact | Cross-session |
| foundry-parallel | Advanced |
| foundry-benchmark | Advanced |
| foundry-review | Delegation |
| foundry-clean | Delegation |

### Subagents (5)

Installed to `~/.claude/agents/foundry-*.md`.

planner, verifier, reviewer, context-builder, refactorer

### Scripts (5)

generate-codemap.sh, check-quality.sh, check-scope.sh, garden-docs.sh, garden-setup.sh

---

## Dogfood Results (2026-03-18)

### Test 1: RPG Notepad (single HTML, no TS)

- SessionStart hook: valid JSON, injected rules + skill guide
- PostToolUse: no-op (no foundry.json in project) — correct
- Result: workflow was theater — no verification to trigger

### Test 2: Hoard (TypeScript CLI, full workflow)

**Hooks tested:**

| Hook | Result |
|------|--------|
| SessionStart | PASS — injected rules + progress + handoff + active plan (8.5K chars) |
| PostToolUse typecheck | PASS — caught missing @types/node, caught TS2532 strict error |
| PostToolUse quality gate | PASS — caught intentional console.log |
| PreToolUse scope guard | PASS — allowed in-scope files, warned on src/utils.ts |
| PreToolUse .md guard | PASS — warned on new .md creation |
| Stop audit | PASS — blocked exit, showed plan status, wrote auto-handoff |
| Session logging | PASS — logged tool calls to .foundry/session-log.jsonl |
| Change counter | PASS — tracked edits in .foundry/.change-count |

**Bugs found & fixed:**

1. PostToolUse `grep -c` integer error — `grep -c` exits 1 on no match + `|| echo 0` doubled the value. Fixed: `grep ...) || CL_COUNT=0`
2. PostToolUse `PIPESTATUS` capture — `|| true` ate exit code. Fixed: removed `|| true`, use bare `$?`

**Live session test (Claude Code):**

- Agent followed TDD (7 failing tests → implement → pass)
- Typecheck caught strict mode issue, agent fixed immediately
- Agent did NOT invoke skills explicitly (worked from rules knowledge)
- Scope guard didn't fire on feature-level scope creep (file-level check only)
- Skills appeared in `/help` after switching from plugin to user-level install

### Installation evolution

1. ~~Plugin approach~~ — symlink to `~/.claude/plugins/cache/`. Claude Code kept pruning the symlink, skills never appeared in `/help`.
2. **User-level install** — copy skills to `~/.claude/skills/`, agents to `~/.claude/agents/`, hooks to `settings.json`. Works reliably.

---

## Known Limitations

1. **Scope guard is file-level only** — can't detect feature-level scope creep within files already in the plan
2. **Stop hook blocks exit** — when quality issues found, may annoy users who just want to quit
3. **Delegation rule always injected** — wastes ~150 tokens when `features.delegation` disabled
4. **Hook scripts use python3** — implicit dependency for JSON parsing, falls back gracefully

## Cascading AGENTS.md + Doc Gardening (2026-03-18)

Restructured documentation from monolith CLAUDE.md → thin router + distributed AGENTS.md files.

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Thin router — pointers only |
| `packages/layer0/AGENTS.md` | L0 gotchas, patterns |
| `docs/AGENTS.md` | Doc organization, what's current vs legacy |
| `docs/decisions.md` | ADRs extracted from PRDs |

### Doc Gardening

Three triggers, all calling `garden-docs.sh`:

| Trigger | Mode | When |
|---------|------|------|
| Post-commit git hook | `HEAD~1..HEAD` | Every commit (immediate, background) |
| Stop hook | `--sweep` | Session end (catches multi-commit sessions) |
| Cron (opt-in) | `--sweep` | Every N min (catches rebases, pulls, manual edits) |

Setup: `bash scripts/garden-setup.sh /path/to/project` (post-commit hook). Add `--cron` for sweep.

Docs scaffolding merged into `/foundry-init` Phase 2 (v0.2.0).

## Superpowers Integration (2026-03-18)

Foundry delegates in-session discipline to Superpowers plugin. Foundry handles infrastructure.

| What changed | Detail |
|---|---|
| New rule: `integration.md` | Bridge rule (~1.1K bytes). Conditionally injected when Superpowers detected. |
| `foundry-plan` v0.2.0 | Now delegates to superpowers:writing-plans. Tells user to install superpowers if missing. |
| `foundry-checkpoint` v0.2.0 | Added superpowers:verification-before-completion gate before commit. |
| `foundry-review` v0.2.0 | Two-stage review (spec + quality) via superpowers when available. Falls back to foundry-reviewer. |
| SessionStart hook | Detects superpowers in plugin cache or skills dir. Skips integration.md if absent. |
| Global CLAUDE.md | Added Foundry × Superpowers section explaining coordination. |
| PRD v3 | Added MS-H0.10 (superpowers integration) to spec. |
| decisions.md | Added "delegate to superpowers, don't duplicate" ADR. |

## Plugin Packaging (2026-03-23)

Packaged Foundry as a Claude Code plugin marketplace (`foundry@foundry`).

| What changed | Detail |
|---|---|
| `.claude-plugin/marketplace.json` | Repo-root marketplace pointing to `./packages/layer0` |
| `migrate.sh` | One-time cleanup of legacy install.sh artifacts |
| `install.sh` | Deprecated — kept for reference |
| Install flow | `/plugin marketplace add` + `/plugin install` |
| `decisions.md` | Revised install ADR — plugin marketplace over user-level |

---

## Next Steps

1. Dogfood integration — use both systems on a real feature, verify coordination
2. Dogfood doc gardening — set up on this repo, make changes, verify auto-updates
3. Dogfood `/foundry-init` Phase 2 — run on a project without cascading context
4. Tune Stop hook — make blocking configurable in foundry.json
5. Filter delegation rule injection based on foundry.json config
6. MS-H1 planning — session wrapper CLI (per v3 PRD)

---

## Architecture Decisions

Moved to [docs/decisions.md](decisions.md).
