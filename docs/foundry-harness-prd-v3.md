# Sub-PRD: Foundry Harness — Agent Orchestration Engine v3

> **Parent:** Foundry Workspace PRD
> **Author:** Boss / Growgami
> **Date:** March 2026
> **Status:** Draft v3 — revised after integration testing; architecture simplified
> **Supersedes:** v2 (bottom-up four-layer)

---

## What Changed From v2

v2 proposed four layers stacked bottom-up. Integration testing exposed a fundamental flaw: **Layer 1-2 wrapped Claude Code as a dumb subprocess**, creating a harness-around-a-harness. Each task launched a cold Claude Code session that re-explored the codebase from scratch, with no shared context between tasks. Verification presets failed to resolve at runtime. Dependency tracking used stale in-memory state. 3 of 8 tasks passed; $1.94 wasted.

The core insight: **Claude Code is already a harness** — it has hooks, subagents, skills, tools, session continuity (`--resume`), and permission modes. Wrapping it externally duplicates what it does internally, but worse (cold starts, no shared context, brittle JSON parsing).

**v3 collapses the architecture:**

| v2 | v3 |
|---|---|
| L0: Claude Code plugin (hooks, skills, rules) | **Unchanged** — still the foundation |
| L1: External CLI wrapper (invoke → verify → retry) | **Simplified** — thin CLI for `--print` invocations, no semantic eval |
| L2: Plan orchestrator (decompose → approve → run via L1) | **Decompose via Claude Code** (not Anthropic API), structured output via `--json-schema` |
| L3: Rust daemon (SQLite, HTTP API, parallel exec) | **Simplified** — one adapter (Claude Code CLI), no API key management, no AgentAdapter trait |

**Key architectural decisions:**
1. **No Anthropic API dependency.** All LLM calls go through `claude --print`. No `ANTHROPIC_API_KEY` needed.
2. **`--json-schema` for structured output.** Claude Code supports it natively; output goes to `structured_output` field (not `result`).
3. **`--continue` / `--resume` for session continuity.** Failed tasks can retry in the same session context instead of cold-starting.
4. **Kill semantic evaluation.** Running a full Claude Code session to eval a diff is absurdly expensive without direct Haiku API access. External verification (lint/test/typecheck) is the sole pass/fail signal.
5. **Verification presets must be bundled or resolved reliably.** v2's path resolution silently failed, producing zero-check "passes."

---

## Context

### Problem (unchanged from v2)

1. **The context window cliff.** Complex features hit context limits around task 7-8. Everything learned is lost.
2. **No verification loop.** Claude Code declares success based on self-assessment. No external typecheck/test/lint enforcement.
3. **No structured retry.** When tasks fail, humans manually reconstruct context.

### Solution

Foundry Harness is built **bottom-up in four layers**, each delivering standalone value:

```
Layer 3: Daemon + UIs         ← Rust daemon, subprocess management, queue, API for UIs
Layer 2: CLI Orchestrator     ← Multi-task plans, dependency ordering, sequential execution
Layer 1: Session Wrapper      ← External verification, retry, state tracking
Layer 0: Claude Code Core     ← Hooks, skills, commands, subagents inside Claude Code
```

**Layer 0** makes Claude Code itself better — structured workflows, progress tracking, context bridging, continuous verification via PostToolUse hooks, and disciplined development practices enforced from inside the agent session.

**Layer 1** wraps Claude Code sessions with external verification, retry logic, and state persistence. Invokes Claude Code as subprocess via `claude --print --output-format json`. Runs checks after it finishes, retries on failure, logs results. No semantic evaluation — external verification only.

**Layer 2** adds multi-task orchestration — decomposition (via Claude Code with `--json-schema`, not Anthropic API), dependency ordering, sequential execution, plan approval. Builds on Layer 1's verified single-task execution.

**Layer 3** is the Rust daemon — a systemd service with HTTP API, WebSocket streaming, subprocess management, and crash recovery. No Anthropic API calls, no AgentAdapter trait — one adapter: Claude Code CLI subprocess. Parallel execution via git worktrees with multiple `claude` processes.

### Design Principles

1. **The system runs the model, not the reverse.** The harness controls the loop — what task, what context, what tools, what verification, when to stop.
2. **Tasks are one-shot and stateless.** Each agent invocation gets a fresh session with assembled context. The harness is the memory.
3. **File-system-as-state.** Progress is persisted to files — not held in any agent's context window.
4. **External verification is non-negotiable.** The agent's opinion about whether code works is irrelevant.
5. **Context engineering is the primary cost and quality lever.** What you put in the prompt is more important than which model you use.
6. **No API key dependency.** Everything goes through `claude --print`. The harness works with just Claude Code installed.

### Claude Code CLI Flags (verified)

The subprocess interface supports all needed capabilities:

| Flag | Purpose |
|---|---|
| `--print` / `-p` | Non-interactive mode, print response and exit |
| `--output-format json` | Structured JSON output (result, cost, session_id, usage) |
| `--output-format stream-json` | Real-time newline-delimited JSON events |
| `--system-prompt` | Replace default system prompt |
| `--append-system-prompt` | Append to default system prompt |
| `--model sonnet\|opus` | Model selection (aliases or full IDs) |
| `--max-turns N` | Limit agent turns (print mode only) |
| `--json-schema '{...}'` | Enforce structured output → `structured_output` field |
| `--max-budget-usd N` | Cost cap per invocation |
| `--no-session-persistence` | Ephemeral sessions |
| `--continue` / `-c` | Resume most recent conversation |
| `--resume <id>` | Resume specific session by ID |
| `--allowedTools` | Whitelist tools (permission rule syntax) |
| `--disallowedTools` | Blacklist tools from model context |
| `--dangerously-skip-permissions` | Headless permission bypass |
| `--verbose` | Full turn-by-turn output |

---

## Usage Scenarios

### Scenario 1: Layer 0 — Claude Code is more disciplined out of the box

Klyde starts a Claude Code session to add rate limiting. Foundry's L0 hooks and skills are installed. On session start, the `UserPromptSubmit` hook injects progress context and methodology. Claude Code plans before coding via `/foundry:plan`. PostToolUse hooks run `tsc --noEmit` after every `.ts` edit, catching type errors immediately. The Stop hook writes a handoff note. No external tooling ran.

### Scenario 2: Layer 1 — Verified, retried single-task execution

```bash
foundry exec --task "Migrate users table: add role column" --verify node-typescript --retries 2
```

The wrapper launches `claude --print`, captures structured output, runs external verification. On failure, retries with enriched context + model escalation (sonnet → opus). No semantic evaluation — lint/test/typecheck is the sole signal.

### Scenario 3: Layer 2 — Multi-task plan with dependency ordering

```bash
foundry decompose --prd docs/prometheus-ms2.md --project ./
```

Decomposition runs through Claude Code with `--json-schema` for structured output (not Anthropic API). Output goes to `structured_output` field. The orchestrator creates a plan, user approves, tasks execute sequentially through Layer 1.

### Scenario 4: Layer 3 — The daemon runs while Klyde is AFK

Same as above, but the Rust daemon processes the queue overnight. No Anthropic API dependency — just spawns `claude` subprocesses. Parallel execution via git worktrees.

---

## Milestones

### MS-H0: Claude Code Enhancement Layer

The foundation — hooks, skills, rules, subagents inside Claude Code. See v2 PRD for original spec of:
- 0.1 Session Lifecycle Hooks (SessionStart, PostToolUse, PreToolUse, Stop)
- 0.2 Foundry Rules (workflow.md, scope.md, quality.md, context.md, git.md, delegation.md)
- 0.3 Foundry Skills (16 invocable + 1 bootstrap)
- 0.4 Foundry Subagents (planner, verifier, reviewer, context-builder, refactorer)
- 0.5 Project Configuration (foundry.json)
- 0.6 Installation (user-level install, `bash install.sh`)

#### 0.9 Cascading Context System (added v3.1)

CLAUDE.md as thin router → AGENTS.md per directory → decisions.md for ADRs. Doc gardening via three triggers: post-commit git hook (immediate), Stop hook (session sweep), cron (opt-in periodic sweep). `/foundry-init` Phase 2 scaffolds the pattern in any project. `garden-docs.sh` and `garden-setup.sh` automate maintenance.

#### 0.10 Superpowers Integration (added v3.1)

Foundry L0 coexists with the Superpowers plugin (anthropics/claude-code marketplace). Rather than duplicating workflow skills, Foundry delegates in-session discipline to Superpowers where it's stronger:

| Foundry owns | Superpowers owns |
|---|---|
| Hooks (reactive verification, scope guard, quality gates) | Planning (writing-plans, review loop, bite-sized steps) |
| Cross-session state (progress, handoff, codemap) | Execution (subagent-driven-development, executing-plans) |
| Context bridging (foundry-context, foundry-compact) | Debugging (systematic-debugging, root-cause tracing) |
| Doc gardening (AGENTS.md, garden-docs.sh) | Verification gate (verification-before-completion) |
| Project config (foundry.json) | TDD discipline (test-driven-development) |
| Scope guard (PreToolUse hook) | Branch finishing (finishing-a-development-branch) |
| Doc scaffolding + project init (foundry-init) | Code review (requesting/receiving-code-review) |
| | Parallel dispatch (dispatching-parallel-agents) |
| | Brainstorming (brainstorming) |

Coordination via `rules/integration.md` injected by SessionStart when Superpowers is detected. Foundry skills that overlap (foundry-plan, foundry-review, foundry-checkpoint) become thin wrappers that delegate to Superpowers for the workflow and handle Foundry-specific state management (progress tracking, plan file location, scope registration).

When Superpowers is NOT installed, Foundry skills work standalone — no dependency.

---

### MS-H1: Session Wrapper

**Changes from v2:**
- **Kill semantic evaluation** (§1.3 removed). Without direct Haiku API access, running a full Claude Code session to evaluate a diff is absurdly expensive. External verification (lint/test/typecheck) is the sole pass/fail signal.
- **Fix verification preset resolution.** Presets must be bundled into the CLI dist or resolved from a well-known path. The v2 bug: preset files were searched at runtime paths that didn't exist in the test project.
- **Read `structured_output` field** when `--json-schema` is used, not `result`.
- **Session continuity on retry.** Use `--continue` to retry failed tasks in the same session context instead of cold-starting a new session. This preserves the agent's understanding of the codebase.

#### 1.1 Core Execution Loop

```
receive task → assemble context → invoke claude --print → capture output
    → run external verification → [pass: commit + log] / [fail: retry or escalate]
```

- **Task input:** JSON file or inline string. Same schema as v2.
- **Context assembly — two-tier prompt structure:**
  - **System prompt** (via `--system-prompt` or `--append-system-prompt`): task description, acceptance criteria, constraints, scope restrictions
  - **Piped context** (via stdin): relevant files, progress file, CLAUDE.md, codemap, retry errors
- **Output parsing:** extract from Claude Code's JSON response: `result`, `structured_output` (when `--json-schema` used), `cost`, `session_id`, `num_turns`, `duration_ms`
- **Model selection:** via `--model` flag. Supports aliases (`sonnet`, `opus`, `haiku`) and full model IDs.

#### 1.2 External Verification Pipeline

After the agent exits successfully, run verification commands from the project's preset:

- Execute each command sequentially in the task's `working_dir`
- Capture exit code, stdout, stderr, duration for each
- **Short-circuit on first required failure**
- Return structured result: `{ passed: bool, results: [...] }`

**Preset resolution (FIXED):**
1. Project-local: `<dir>/.foundry/presets/<preset>.json`
2. Bundled: embedded in CLI build via import (no filesystem dependency)
3. Fallback: if no preset found, run `tsc --noEmit` if `tsconfig.json` exists

#### 1.3 Retry Engine

On verification or agent failure:

- Check `retry_count < max_retries`
- **Model escalation:** sonnet → opus on retry (if enabled)
- **Session continuity:** use `--continue` for retries (same session context, not cold start)
- Assemble retry context: original task + error output + previous diff + failed approaches from progress file
- After max retries: mark as `failed_needs_human`, print diagnostic summary

**Retry escalation:**
- Attempt 1: original prompt (sonnet)
- Attempt 2: enriched context + `--continue` (opus if escalation enabled)
- Attempt 3: enriched + hint to try different approach
- After max: `failed_needs_human`

#### 1.4 State & Logging

Same as v2: file-based state in `.foundry/executions/`, git integration (auto-commit on pass, stash on fail).

#### 1.5 CLI Interface

```bash
foundry exec --task "..." --dir ./project --verify node-typescript
foundry exec --task-file task.json --retries 3 --model opus
foundry verify --dir ./project --preset node-typescript
foundry log [task-id] [--last]
foundry agent check
```

**Removed:** `foundry benchmark` (move to L0 skill), `--mode phased` (simplify to direct execution only).

---

### MS-H2: Plan Orchestrator

**Changes from v2:**
- **Decomposition via Claude Code, not Anthropic API.** Uses `claude --print --json-schema '...'` for structured output. Output is in `structured_output` field. No `@anthropic-ai/sdk` dependency, no `ANTHROPIC_API_KEY`.
- **Fix stale plan state bug.** The runner must re-read the plan from disk before each dependency check, not use a stale in-memory copy.
- **Two-phase decomposition still works** — just two `claude --print` invocations instead of two API calls.

#### 2.1 Decomposition Engine

- Invokes `claude --print --output-format json --json-schema '<DecompositionResultSchema>'` with assembled context
- Reads `structured_output` field from response (not `result`)
- If `structured_output` is empty/malformed, falls back to `result` field with `extractJson()` + Zod validation
- Model: `--model sonnet` (default for planning)
- Same input context as v2: objective, file tree, CLAUDE.md, foundry.json, progress file

#### 2.2 Plan Data Model

Same as v2. File-based JSON in `.foundry/plans/`.

**Added fields:**
- `feedback?: string` — rejection feedback
- `rejection_count: number` — how many times rejected

#### 2.3 Approval Flow

Same as v2 plus:
- `foundry plan edit <id> <task-id> [--description] [--depends-on] [--files]`
- `foundry plan add <id> --description "..." [--depends-on]`
- `foundry plan remove <id> <task-id>` — cascades dependency removal
- `foundry plan reject <id> --feedback "..."` — auto re-decomposes

All edit/add/remove operations validate the DAG after modification.

#### 2.4 Plan Execution Engine (FIXED)

Sequential execution following topological sort:

1. Create feature branch
2. Resolve execution order via topological sort (Kahn's algorithm)
3. For each task in order:
   a. **Re-load plan from disk** (fix stale state bug)
   b. Check all dependencies are `completed`. If any is `failed`, mark as `blocked` and skip.
   c. Assemble task context
   d. Invoke Layer 1's execution loop
   e. On success: update plan task status on disk, commit
   f. On failure after retries: mark `failed_needs_human`, continue to independent tasks
4. Mark blocked tasks (transitive closure of failed dependencies)
5. Final plan status: `completed` if all pass, `failed` otherwise

#### 2.5 CLI

```bash
foundry decompose --prd <file> [--inline "..."] [-m model] [--two-phase]
foundry plan list | show <id> | approve <id> | cancel <id>
foundry plan edit <id> <task-id> | add <id> | remove <id> <task-id> | reject <id>
foundry run <plan-id> [--dry-run] [--from <task-id>]
```

---

### MS-H3: Rust Daemon

**Changes from v2:**
- **No `reqwest` dependency.** No HTTP calls to Anthropic API. All LLM calls are `claude` subprocess invocations.
- **No `AgentAdapter` trait.** One adapter: Claude Code CLI subprocess. If other agents are added later, add the trait then. YAGNI.
- **No API key management.** No token-level billing. Cost comes from Claude Code's own reporting.
- **Simpler architecture:** task queue + subprocess management + verification + state + API for UIs.

#### 3.1 Daemon Core

- Rust binary with `tokio`, `axum`, `rusqlite`
- systemd integration, signal handling, crash recovery
- Spawns `claude --print` subprocesses per task
- Uses `--output-format stream-json` for real-time progress

#### 3.2 State Migration: Files → SQLite

Same schema as v2. WAL mode, migrations embedded in binary.

#### 3.3 HTTP API

Same as v2.

#### 3.4 Claude Code Adapter (simplified)

```rust
pub struct ClaudeCodeAdapter {
    claude_path: PathBuf,
}

impl ClaudeCodeAdapter {
    pub async fn execute(&self, request: &TaskRequest) -> Result<TaskResponse> {
        // Spawn: claude --print --output-format json --model <model> ...
        // Parse JSON response
        // Return structured result
    }
}
```

No trait. No multi-adapter. Just the one adapter that works.

#### 3.5 CLI becomes thin client

Same as v2.

#### 3.6 Parallel Execution

- Multiple `claude` subprocesses in separate git worktrees
- No API concurrency limits to worry about — Claude Code manages its own rate limiting
- Resource-aware: monitor system RAM, pause spawns if constrained

#### 3.7 Daemon Safety

Same as v2 (systemd unit, watchdog, log rotation).

#### 3.8 Rust Dependencies (simplified)

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
axum = "0.8"
rusqlite = { version = "0.32", features = ["bundled"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
toml = "0.8"
clap = { version = "4", features = ["derive"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["json"] }
tracing-appender = "0.2"
tokio-tungstenite = "0.24"
git2 = "0.19"
notify-rust = "4"
```

**Removed:** `reqwest` (no API calls).

---

## Architecture Summary (v3)

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 3: Rust Daemon (MS-H3)                                   │
│  ┌─────────────┐ ┌──────────┐ ┌──────────┐ ┌────────────────┐  │
│  │ HTTP API    │ │ WebSocket│ │ SQLite   │ │ Resource Mon.  │  │
│  │ (axum)      │ │ Streaming│ │ State    │ │ Crash Recovery │  │
│  └──────┬──────┘ └────┬─────┘ └────┬─────┘ └───────┬────────┘  │
│         └──────────────┴───────────┴────────────────┘           │
│                              │                                   │
├──────────────────────────────┼───────────────────────────────────┤
│  Layer 2: Plan Orchestrator (MS-H2)                              │
│  ┌──────────────┐ ┌─────────────┐ ┌───────────────────────────┐ │
│  │ Decomposer   │ │ Dependency  │ │ Plan Executor             │ │
│  │ (claude      │ │ Graph +     │ │ (sequential, feeds tasks  │ │
│  │  --print     │ │ Topo Sort   │ │  to Layer 1 loop)         │ │
│  │  --json-     │ │             │ │                           │ │
│  │  schema)     │ │             │ │ Re-reads plan from disk   │ │
│  └──────────────┘ └─────────────┘ │ before each dep check     │ │
│                                   └─────────────┬─────────────┘ │
│                                                  │               │
├──────────────────────────────────────────────────┼───────────────┤
│  Layer 1: Session Wrapper (MS-H1)                │               │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────┴─────────┐   │
│  │ Context      │ │ External     │ │ Retry Engine          │   │
│  │ Assembly     │ │ Verification │ │ (--continue for       │   │
│  │              │ │ Pipeline     │ │  session continuity)  │   │
│  └──────┬───────┘ └──────┬───────┘ └───────────┬───────────┘   │
│         └────────────────┴─────────────────────┘               │
│                              │ invokes claude --print            │
├──────────────────────────────┼───────────────────────────────────┤
│  Layer 0: Claude Code Plugin (MS-H0) — UNCHANGED                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ HOOKS │ RULES │ SKILLS │ SUBAGENTS │ STATE              │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │ runs inside                       │
├──────────────────────────────┼───────────────────────────────────┤
│  Claude Code Session         │                                   │
│  (with Foundry plugin)                                           │
└─────────────────────────────────────────────────────────────────┘
```

### What each layer can do independently

| You have... | You can... |
|---|---|
| Layer 0 only | Continuous typecheck, quality gates, scope guard, progress tracking, codemap, cross-session handoff, doc gardening, cascading AGENTS.md, desktop notifications |
| Layer 0 + Superpowers | All above + disciplined planning (bite-sized, reviewed), subagent-driven execution, systematic debugging, TDD enforcement, verification gate, parallel agent dispatch, branch finishing |
| Layer 0 + 1 | All above + fire-and-forget single tasks, external verification pipeline, retries with session continuity + model escalation, structured execution logs |
| Layer 0 + 1 + 2 | All above + multi-task plan execution from PRD decomposition (via Claude Code, no API key), dependency ordering, plan editing/rejection, two-phase decomposition |
| Layer 0 + 1 + 2 + 3 | All above + always-on daemon, parallel execution via worktrees, SQLite state, WebSocket streaming, crash recovery |

---

## Bugs Found During v2 Integration Test

These informed the v3 changes. Preserved here for reference:

| Bug | Root Cause | v3 Fix |
|---|---|---|
| ANTHROPIC_API_KEY required for decompose | Decompose used Anthropic SDK directly | All calls through `claude --print` |
| Verification never ran (all `verify=n/a`) | Preset file path resolution failed silently | Bundle presets or fallback to sensible defaults |
| Blocked tasks executed (wasted $) | In-memory plan state stale after disk writes | Re-read plan from disk before each dep check |
| $0 cost on failed tasks | Cost only parsed from `result.ok` branch | Parse cost from stdout JSON on all outcomes |
| Empty error summaries | stderr only captured on subprocess failure | Capture verification failure output as error context |
| `--json-schema` output in wrong field | Read `result` instead of `structured_output` | Read correct field |
| Plan status never finalized | No cleanup on process exit | Ensure plan status written in finally block |
| Claude returned markdown despite JSON instruction | System prompt lacked explicit JSON-only instruction | Add schema example to system prompt + use `--json-schema` |

---

## Implementation Order

| Milestone | Effort | Stack | Status |
|---|---|---|---|
| MS-H0 (core) | 2-3 weeks | Markdown, shell, JSON | Done, dogfooded |
| MS-H0.9 (cascading context) | 2-3 days | Markdown, shell | Done |
| MS-H0.10 (superpowers integration) | 2-3 days | Markdown, shell | Planned |
| MS-H0.11 (plugin packaging) | 1-2 days | JSON, shell | Not started |
| MS-H1 | 2-3 weeks | Node.js/TypeScript | Not started (v2 CLI deleted) |
| MS-H2 | 2-3 weeks | Node.js/TypeScript | Not started |
| MS-H3 | 3-4 weeks | Rust | Not started |

#### 0.11 Plugin Packaging (added v3.2)

Foundry L0 is currently installed via raw hook entries in `~/.claude/settings.json` pointing to local paths. This is fragile, non-portable, and inconsistent with how superpowers/frontend-design/gg-conventions are distributed (as plugins via marketplaces).

**Goal:** Package Foundry as a standalone Claude Code plugin marketplace (`foundry@foundry`), so it installs/uninstalls/updates like any other plugin.

**What this means:**
- Foundry repo becomes its own marketplace (like `claude-plugins-official` or `gg-skills`)
- Contains one plugin: `foundry` — with hooks, skills, agents, rules bundled
- Plugin ID: `foundry@foundry`
- Registered in `known_marketplaces.json` as a directory source pointing to the repo

**Repo structure changes:**
```
foundry/
├── .claude-plugin/
│   └── marketplace.json          ← top-level marketplace registry
├── plugins/
│   └── foundry/
│       ├── .claude-plugin/
│       │   └── plugin.json       ← move from packages/layer0/
│       ├── hooks/                ← move from packages/layer0/hooks/
│       ├── skills/               ← move from packages/layer0/skills/
│       ├── agents/               ← move from packages/layer0/agents/
│       ├── rules/                ← move from packages/layer0/rules/
│       └── templates/            ← move from packages/layer0/templates/
├── docs/                         ← unchanged
└── ...
```

**Installation (replaces manual hook wiring):**
1. Register marketplace: `foundry` → `{ source: "directory", path: "<repo-path>" }` in `known_marketplaces.json`
2. Enable plugin: `"foundry@foundry": true` in `enabledPlugins`
3. Remove 4 manual hook entries from `settings.json` (SessionStart, PreToolUse, PostToolUse, Stop)

**Plugin manifest must declare:**
- Hooks (all 4 lifecycle hooks currently in settings.json)
- Skills (17 foundry skills + using-foundry bootstrap)
- Agents (5 subagent definitions)
- Rules (injected via SessionStart)

**Migration:** One-time script that moves hook config from settings.json into plugin manifest and registers the marketplace.

**Why not under gg-skills:** Foundry is a standalone project, not a Growgami convention. Should be installable independently.

**Resolved:**
- Plugins DO support hooks in plugin.json — either inline or via `"hooks": "./hooks/hooks.json"`. Superpowers uses file-based, hookify uses inline. Both patterns work.
- Single-plugin marketplaces are fine — `ralph-loop-setup` is precedent.

**Unresolved:**
- How does `install.sh` change — does it register the marketplace + enable, or does `claude plugins add` handle it?
- L1-L3 (CLI, orchestrator, daemon) live outside the plugin. Repo restructure must not break their paths.

---

**Immediate priorities:**
1. MS-H0.10 — Superpowers integration (bridge rule, skill wrappers, SessionStart detection)
2. MS-H0.11 — Plugin packaging (marketplace structure, migration script)
3. Dogfood integration on a real project
4. Dogfood doc gardening
5. MS-H1 planning — session wrapper CLI
