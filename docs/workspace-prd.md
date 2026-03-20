# PRD: Foundry — Personal Development Workspace & Agent Harness

> **Working title:** Foundry (open to rename)
> **Author:** Boss / Growgami
> **Date:** March 2026
> **Status:** Draft v1

---

## Context

### Customer Messaging

Your coding agents are powerful but chaotic. Foundry is the operating system that makes them reliable — a personal workspace daemon that decomposes your work into tasks, orchestrates AI agents to execute them, verifies results, and keeps you in control of every decision. Start with one agent, scale to many. Your machine, your rules.

### Problem

AI coding agents (Claude Code, Codex, Aider) are individually capable but operationally dumb. They have no memory between sessions, no concept of a project's overall state, no ability to self-verify, and no way to coordinate multi-step work across context window boundaries. The developer is the harness — manually decomposing work, deciding what to feed the agent, checking results, retrying failures, and tracking progress across sessions.

This creates three concrete pains:

**Context loss.** A Claude Code session runs out of context window on step 7 of 12. Everything learned in that session — architectural decisions, failed approaches, intermediate state — evaporates. The developer manually reconstructs context for the next session by re-explaining the project, pointing to files, and re-establishing constraints. This is the single largest source of wasted time and tokens.

**No orchestration.** If a PRD has 15 features across 3 milestones, the developer manually sequences them, decides dependencies, runs each one, checks if it worked, and tracks what's done. There's no queue, no retry logic, no parallelism, and no persistent record of what was attempted vs. what succeeded. The developer's brain is the task queue, and it doesn't scale.

**Tool sprawl.** Tracking work requires Linear or similar. Monitoring agent runs requires watching terminal output. Reviewing results requires switching to the editor. Understanding what happened requires reading git logs. There's no unified surface that answers "what's the state of my project right now?" — and once the workspace grows to include goals, notes, and summaries, the fragmentation gets worse.

### Solution

Foundry is a Rust daemon running as a systemd service on Linux, with a TypeScript web UI and a terminal UI. It starts as an agent harness and grows into a full personal development workspace.

The daemon manages the core loop: accept a high-level objective → decompose it into atomic tasks (LLM-proposed, human-approved) → queue tasks with dependency ordering → execute each task by invoking a coding agent as a subprocess → verify results via automated checks → retry or escalate failures → persist state across everything.

The architecture is agent-agnostic by interface but Claude Code-first by implementation. A well-defined `AgentAdapter` trait in Rust means adding Codex, Aider, or a custom API-based agent later is a matter of implementing one interface, not restructuring the system.

The web UI is the command center — task board, execution logs, approval workflows, and project state at a glance. The terminal UI (Rust TUI via ratatui) is for quick interactions — approving tasks, checking status, tailing logs — without leaving the terminal.

### Why Now

Three things converged. First, Claude Code's plugin system and structured output matured enough that wrapping it programmatically is now reliable — earlier versions were too fragile for unattended orchestration. Second, the research on agent harnesses (Anthropic's long-running agent patterns, Stripe's Minions architecture, Factory AI's Droid) has crystallized best practices that didn't exist 6 months ago. Third, you're transitioning from freelance (Growgami) to employment (PATONA/Teamified) and need a personal infrastructure that works across professional contexts — owned by you, running on your machine, not locked to any employer's tooling.

### Why We Deserve to Win

This isn't a product for the market — it's a personal workspace built by a developer who understands both the agent orchestration patterns (from building Prometheus, CreatorBounty, SlopKill, and extensive Claude Code workflow experimentation) and the systems programming needed to make it reliable (CachyOS/Arch daily driver, systemd services, Docker, production server hardening). The Rust daemon isn't a resume flex — it's the right tool for a long-running process that must not leak memory, must recover from crashes, and must be safe to leave running permanently on a daily-driver machine.

### Options Considered

**Shell scripts wrapping Claude Code.** Too fragile. No state persistence, no retry logic, no parallelism, no UI. Fine for one-off tasks, not for sustained orchestration.

**Node.js daemon with BullMQ.** Viable and matches the existing stack, but Node's garbage collector and event loop are not ideal for a process that runs 24/7 for months. Memory leaks in long-running Node processes are a known operational headache. Rust eliminates this class of problem entirely.

**Existing frameworks (LangGraph, CrewAI, Mastra).** These are agent-building frameworks, not personal workspace daemons. They solve orchestration within a single execution but don't provide the persistent daemon, task tracking, approval workflows, or UI that Foundry needs. They could be used as components within Foundry, but adopting one wholesale would mean building the workspace on top of someone else's abstraction.

**Using Linear/Notion + manual orchestration.** The current approach. Works, but doesn't scale, requires constant manual intervention, and fragments state across multiple tools.

### Prior Art

**Stripe's Minions:** The closest production analog — blueprints alternating deterministic code with bounded agent loops, Toolshed MCP server for tools, devbox isolation, capped CI rounds. Key lessons: constrain the agent, make tasks one-shot, cap retries.

**Anthropic's Claude Code harness patterns:** Two-agent pattern for long-running tasks (initializer + coding agents bridged by progress files and git), context compaction, subagent isolation. Key lesson: file-system-as-state for cross-session persistence.

**OpenAI Codex CLI:** Stateless requests with prompt caching, three-tier sandboxing (read-only, workspace-write, full-access), AGENTS.md cascading configuration. Key lesson: prompt caching via stable prefixes dramatically reduces cost.

**Factory AI's Droid:** Hierarchical multi-agent with Spec → Test → Implement → Verify → Close loop, delegator never writes code. Key lesson: separation of planning and execution improves reliability.

**Replit Agent:** Evolution from ReAct loop to three-agent architecture (manager, editor, verifier) with Mastra + Inngest for durable execution. Key lesson: durable execution infrastructure (not just retry logic) is what makes agents production-grade.

---

## Usage Scenarios

### Scenario 1: Klyde ships Milestone 2 of Prometheus while AFK

It's a Wednesday evening in March 2026. Klyde has the Prometheus clone PRD open — a TikTok marketing research AI agent with 4 milestones. Milestone 1 (MCP server scaffold, basic TikTok data fetching) is done. Milestone 2 has 8 features: trend analysis pipeline, content scoring, competitor tracking, report generation, and four supporting infrastructure pieces.

Klyde opens the Foundry web UI, pastes the Milestone 2 section of the PRD, and hits "Decompose." Foundry makes an API call to Claude and returns a proposed task list: 11 tasks with dependency arrows — infrastructure tasks first, then the pipeline components that depend on them, then the report generator that depends on everything. Three tasks are flagged as parallelizable. Each task has a description, target files, acceptance criteria (specific test assertions), and an estimated context budget.

Klyde scans the list. He drags "Set up Redis Streams consumer" above "Implement trend analysis" because he knows the consumer pattern will inform the analysis architecture. He edits one acceptance criterion to be more specific. He approves the plan.

Foundry queues 11 jobs. The first three (infrastructure) start executing — each one launches a Claude Code subprocess in the project directory with Superpowers installed, a focused context package (only relevant PRD section, only target files, architectural constraints from CLAUDE.md), and a task-specific system prompt. Klyde watches the first task complete in the web UI — green checkmark, tests passing, git commit with a descriptive message. He closes his laptop and rides his Keeway to the gym.

Two hours later, he checks his phone. The Foundry web UI shows: 8 tasks complete, 1 in progress, 1 waiting on dependency, 1 failed after 2 retries (a Redis Streams edge case the agent couldn't figure out). The failed task has a detailed log — the agent's reasoning, the test output, what it tried on each retry. Klyde opens his terminal, runs `foundry status`, sees the same summary. He'll handle the failed task manually tomorrow — or just re-queue it with an added hint about the edge case.

### Scenario 2: Klyde onboards at PATONA with Foundry as his silent co-pilot

It's April 2026, first week at PATONA/Teamified. Klyde gets assigned a mid-size feature — integrating a new payment provider. The codebase is unfamiliar, the conventions are different from his Growgami projects. He can't use Foundry's full orchestration mode (the repo belongs to PATONA, and the agent needs guardrails).

He switches Foundry to "advisor mode" via the TUI: `foundry mode advisor`. In this mode, Foundry doesn't execute agents — it only decomposes. Klyde describes the feature, Foundry proposes a task breakdown with dependency ordering and estimated complexity. Klyde uses this as his personal work plan — he works through the tasks manually (or with Claude Code directly), but Foundry tracks his progress, maintains a running summary of what's done, and keeps notes on architectural decisions he's making. The task tracker (a future milestone of Foundry itself) replaces his need for a separate Linear board for personal work tracking.

When he encounters a gnarly bug in the payment provider's webhook handling, he uses Foundry's TUI to capture the bug context (error logs, relevant files, what he's already tried) and queues a focused Claude Code session specifically scoped to debugging — not implementation, just analysis. The agent runs in read-only mode, produces a diagnosis, and Klyde applies the fix himself.

### Scenario 3: Klyde uses Foundry to maintain his open-source projects while employed

It's June 2026. Klyde has three repos that need maintenance — Prometheus (now open-sourced), a utility library, and his Hatch platform. He doesn't have time for deep feature work, but issues are piling up: dependency updates, bug reports, documentation gaps.

Every Sunday evening, Klyde opens the Foundry web UI and reviews the week's accumulated tasks — some auto-generated from GitHub issue webhooks, some he added manually via TUI during the week. He spends 15 minutes triaging: approving the straightforward ones (dependency bumps, typo fixes, doc updates), editing the complex ones to add context, rejecting the ones that need more thought.

He hits "Execute batch" and goes to sleep. Foundry processes the queue overnight — each task gets its own Claude Code session, its own git branch, its own verification pipeline. By morning, there are 12 draft PRs waiting for his review. He reviews them over coffee on his phone via the Foundry web UI, which shows a diff summary and test results for each. Merge the clean ones, close the ones that missed the mark with a note for next week.

---

## Milestones

### MS1: Daemon Core + Claude Code Adapter ("It runs")

**Goal:** A working Rust daemon that can receive a task, execute it via Claude Code, verify the result, and persist state. Prove the core loop works end-to-end on a single task before adding orchestration complexity.

**Scope:**

- **Rust daemon scaffold** — systemd service unit, graceful shutdown (SIGTERM/SIGINT), structured logging (tracing crate), PID file, health check endpoint
- **SQLite persistence layer** — task table (id, status, description, context, result, attempts, created_at, updated_at), execution log table (task_id, attempt, stdout, stderr, exit_code, duration, tokens_used), configuration table
- **Claude Code adapter** — invoke `claude` CLI as subprocess with `--output-format json` and `--print` flags, capture structured output, parse tool calls/results, handle timeouts and crashes, respect the `AgentAdapter` trait interface
- **`AgentAdapter` trait** — define the Rust trait that all future agent adapters must implement: `fn execute(task: &Task, context: &TaskContext) -> Result<ExecutionResult>`, `fn health_check() -> Result<AgentStatus>`, `fn capabilities() -> AgentCapabilities`
- **Task execution pipeline** — single-task flow: receive task → assemble context (task description + file paths + constraints) → invoke agent → capture output → run verification commands (configurable per-task: lint, test, typecheck) → update task status → commit to git if successful
- **Basic HTTP API** — REST endpoints for: submit task, get task status, get execution logs, health check. This is the interface both UIs will consume.
- **Configuration** — TOML config file at `~/.config/foundry/config.toml` covering: agent binary path, default project directory, verification commands, retry policy (max attempts, backoff), resource limits (max concurrent tasks for MS1 = 1)
- **Basic CLI** — `foundry start`, `foundry stop`, `foundry status`, `foundry submit <task-file.json>`, `foundry logs <task-id>`

**Out of scope for MS1:** Web UI, TUI, task decomposition, dependency ordering, parallelism, approval workflows, context engineering beyond basic file inclusion.

**De-risk:** Can Claude Code be reliably invoked as a subprocess with structured output, and can the daemon recover cleanly when Claude Code crashes, hangs, or produces unexpected output? This is the single highest-risk technical question — if this doesn't work reliably, the entire architecture needs rethinking.

**Tech decisions to lock in:**
- Rust async runtime: **tokio**
- HTTP framework: **axum**
- Database: **SQLite via rusqlite** (single-user, local-first, zero ops)
- Serialization: **serde + serde_json**
- CLI: **clap**
- Logging: **tracing + tracing-subscriber**
- Process management: **tokio::process**

---

### MS2: Task Decomposition + Approval Flow ("It plans")

**Goal:** Foundry can take a high-level objective (PRD section, feature description, bug report) and propose an ordered task list. The user reviews, edits, and approves before execution begins. This is the semi-automatic brain.

**Scope:**

- **Decomposition engine** — takes a text objective + optional file context, calls Claude API (not Claude Code — this is a structured output call via the Anthropic API directly) with a decomposition prompt, returns a structured task list with: task descriptions, target file paths, acceptance criteria, dependency edges, estimated context budget, parallelizability flags
- **Dependency graph** — topological sort for execution ordering, parallel group detection, cycle detection with clear error messages
- **Approval workflow** — proposed task list is stored with status `pending_approval`, exposed via API. User can: approve all, approve individually, edit any task's description/criteria/dependencies, reorder tasks, reject and re-decompose with feedback, add manual tasks to the list
- **Task queue with ordering** — replace MS1's single-task submission with an ordered queue. Respect dependency edges. Execute independent tasks sequentially for MS2 (parallel execution is MS3). Track queue position, blocked-by relationships, estimated time remaining.
- **Context assembly engine** — for each task, assemble a focused context package: relevant PRD section, target files (read from disk), git diff of what previous tasks in the same plan changed, architectural constraints from CLAUDE.md or Foundry config, error output from previous failed attempt (if retry). Token budget estimation to warn if context will exceed window.
- **Retry with context** — on task failure, automatically enrich the retry prompt with: the error output, what the agent tried, the specific test/lint failure. Cap at configurable max retries (default: 2). After max retries, mark as `failed_needs_human` and continue to next non-dependent task.
- **Git integration** — each plan gets a feature branch. Each task commits to that branch with a descriptive message. On plan completion, the branch is ready for review/merge. On plan failure, partial progress is preserved on the branch.

**Out of scope for MS2:** Web UI (still API + CLI only), TUI, parallel execution, multiple simultaneous plans, webhook triggers.

**De-risk:** Does LLM-based task decomposition produce task lists that are actually useful — specific enough for single-session execution, correctly ordered by dependency, with meaningful acceptance criteria? This needs empirical testing across different project types (greenfield feature, bug fix, refactor, dependency update) before investing in UI.

---

### MS3: Web UI + Terminal UI ("It has a face")

**Goal:** Both interfaces are functional — the web UI for rich interactions (approval workflows, execution monitoring, log viewing, plan editing) and the TUI for quick terminal-native interactions.

**Scope:**

- **Web UI (Next.js + TypeScript):**
  - Dashboard: active plans, task queue status, recent executions, agent health
  - Plan view: visual task graph (dependency arrows), status colors, click-to-expand task details
  - Approval interface: edit task descriptions inline, drag-to-reorder, approve/reject buttons, add notes
  - Execution monitor: real-time log streaming (WebSocket), per-task stdout/stderr, token usage, cost tracking
  - Task detail: full execution history, diff of changes made, test results, retry log
  - Settings: agent configuration, verification commands, retry policies, project paths

- **Terminal UI (ratatui):**
  - Status dashboard: task queue, active executions, recent results (compact table view)
  - Quick approve: review proposed task list, approve/reject/edit inline
  - Log tail: stream execution output for active tasks
  - Submit: quick task submission from terminal (`foundry tui` launches interactive mode)
  - Keybindings: vim-style navigation, `a` to approve, `r` to reject, `e` to edit, `q` to quit

- **WebSocket layer** — real-time push from daemon to web UI for: task status changes, log streaming, plan updates, agent health events
- **Authentication** — local-only by default (bind to 127.0.0.1). Optional token-based auth for remote access (e.g., checking from phone on same network).

**Out of scope for MS3:** Task tracker / Linear replacement, goals, summaries, multi-project support.

**De-risk:** Can ratatui provide a good enough TUI experience for approval workflows, or will it be too clunky for editing task descriptions? May need to fall back to `$EDITOR` integration for complex edits (open task in nvim/helix, save to update).

---

### MS4: Parallel Execution + Multi-Agent ("It scales")

**Goal:** Execute independent tasks in parallel across multiple agent sessions. Add the second agent adapter (Codex CLI) to validate the `AgentAdapter` trait design.

**Scope:**

- **Parallel execution engine** — configurable max concurrency (default: 3), respects dependency graph (only independent tasks run in parallel), resource-aware scheduling (don't starve the machine — monitor CPU/RAM), each parallel task gets its own git worktree (like Cursor's background agents)
- **Git worktree management** — create worktree per parallel task, merge completed worktrees back to feature branch, handle merge conflicts (mark task as `conflict_needs_human`, provide conflict diff in UI)
- **Codex CLI adapter** — implement `AgentAdapter` for OpenAI Codex CLI, validate that the trait interface works for a fundamentally different agent, document any trait changes needed
- **Agent routing** — per-task agent selection. Default agent from config, override per-task in the plan. Future: automatic routing based on task type and agent capabilities.
- **Resource monitoring** — daemon tracks its own memory usage, CPU time, and child process resource consumption. Configurable limits. Auto-pause queue if system resources are constrained. Expose metrics via the API for UI display.
- **Cost tracking** — per-task and per-plan token usage and estimated cost (pulled from agent output where available). Running totals in the UI.

**Out of scope for MS4:** More than 2 agent adapters, automatic agent selection, distributed execution across machines.

**De-risk:** Git worktree merges for parallel agent work — how often do independent tasks actually produce merge conflicts? Need to test with real codebases to calibrate expectations.

---

### MS5: Personal Workspace ("It's home")

**Goal:** Foundry evolves from "agent harness with UI" into "personal development workspace." The harness is one module within a broader system for managing your work life.

**Scope:**

- **Task tracker** — Linear-style issue tracking built into Foundry. Tasks from agent plans automatically create tracker items. Manual task creation for non-agent work. Status workflow (backlog → todo → in-progress → review → done). Labels, priorities, projects. This replaces Linear for personal use.
- **Project management** — multiple project support. Each project has its own config, agent preferences, verification commands, and git repo. Switch between projects in the UI and TUI.
- **Daily/weekly summaries** — auto-generated summaries of what was accomplished. Git log analysis, task completion stats, time-in-status metrics. Delivered as markdown, viewable in UI, optionally pushed to a notes directory.
- **Goal tracking** — high-level goals that decompose into projects that decompose into plans that decompose into tasks. Progress rolls up from task completion to goal percentage.
- **GitHub integration** — create PRs from completed plans, sync issues from GitHub as Foundry tasks, webhook-triggered task creation from new issues or PR comments.
- **Notification system** — configurable alerts for: task failures, plan completion, tasks needing approval. Channels: desktop notification (via notify-send/libnotify), TUI bell, web UI toast, optional webhook for Telegram/Discord.

**Out of scope for MS5:** Collaboration / multi-user, cloud sync, mobile app.

**Change management:** Migration from external tools (Linear, GitHub Issues as primary tracker) to Foundry's built-in tracker. Should be gradual — Foundry can sync with Linear during transition, then Linear is dropped when Foundry's tracker proves sufficient.

---

## Technical Architecture Notes

*(Not part of the standard PRD framework, but included because this is a personal technical project where architecture is part of the spec.)*

### Daemon Architecture (Rust)

```
foundry-daemon/
├── src/
│   ├── main.rs                 # Entry point, signal handling, systemd integration
│   ├── config.rs               # TOML config parsing (serde)
│   ├── db/
│   │   ├── mod.rs              # SQLite connection pool, migrations
│   │   ├── tasks.rs            # Task CRUD
│   │   ├── plans.rs            # Plan CRUD (decomposed task lists)
│   │   └── executions.rs       # Execution log CRUD
│   ├── agents/
│   │   ├── mod.rs              # AgentAdapter trait definition
│   │   ├── claude_code.rs      # Claude Code subprocess adapter
│   │   └── codex.rs            # (MS4) Codex CLI adapter
│   ├── engine/
│   │   ├── mod.rs
│   │   ├── decomposer.rs       # LLM-based task decomposition
│   │   ├── queue.rs            # Task queue with dependency ordering
│   │   ├── executor.rs         # Task execution loop
│   │   ├── verifier.rs         # Post-execution verification (lint, test, etc.)
│   │   └── context.rs          # Context assembly for each task
│   ├── api/
│   │   ├── mod.rs              # Axum router
│   │   ├── tasks.rs            # Task endpoints
│   │   ├── plans.rs            # Plan/approval endpoints
│   │   ├── logs.rs             # Log streaming (WebSocket)
│   │   └── health.rs           # Health check
│   └── git.rs                  # Git operations (branch, commit, worktree)
├── Cargo.toml
└── foundry.service             # systemd unit file
```

### Key Rust Dependencies

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
tokio-tungstenite = "0.24"    # WebSocket for log streaming
ratatui = "0.29"               # TUI (MS3)
crossterm = "0.28"             # Terminal backend for ratatui
reqwest = { version = "0.12", features = ["json"] }  # Anthropic API calls
git2 = "0.19"                  # libgit2 bindings for git operations
notify-rust = "4"              # Desktop notifications (MS5)
```

### AgentAdapter Trait (Core Interface)

```rust
#[async_trait]
pub trait AgentAdapter: Send + Sync {
    /// Execute a task and return the result
    async fn execute(&self, task: &Task, context: &TaskContext) -> Result<ExecutionResult>;

    /// Check if the agent is available and healthy
    async fn health_check(&self) -> Result<AgentStatus>;

    /// Report what this agent can do
    fn capabilities(&self) -> AgentCapabilities;

    /// Agent identifier (e.g., "claude-code", "codex", "aider")
    fn name(&self) -> &str;
}

pub struct TaskContext {
    pub working_dir: PathBuf,
    pub relevant_files: Vec<PathBuf>,
    pub prd_section: Option<String>,
    pub previous_diff: Option<String>,
    pub constraints: Vec<String>,
    pub error_from_previous_attempt: Option<String>,
    pub token_budget: Option<usize>,
}

pub struct ExecutionResult {
    pub status: ExecutionStatus,  // Success, Failed, Timeout, Crashed
    pub stdout: String,
    pub stderr: String,
    pub exit_code: i32,
    pub duration: Duration,
    pub tokens_used: Option<TokenUsage>,
    pub files_changed: Vec<PathBuf>,
    pub git_commit: Option<String>,
}

pub struct AgentCapabilities {
    pub supports_structured_output: bool,
    pub supports_tool_use: bool,
    pub supports_read_only_mode: bool,
    pub max_context_tokens: Option<usize>,
}
```

### Web UI (Next.js)

Standard Next.js app with App Router. Key libraries:
- **State:** React Query (TanStack Query) for server state, Zustand for UI state
- **Realtime:** native WebSocket client for log streaming
- **UI:** shadcn/ui components, Tailwind CSS
- **Charts:** Recharts for cost/token tracking visualizations
- **Task graph:** React Flow or d3-dag for dependency graph visualization

### Data Flow

```
User (Web UI / TUI / CLI)
    │
    ▼
HTTP API (axum)  ◄──── WebSocket (real-time logs/status)
    │
    ▼
Engine
    ├── Decomposer ──► Anthropic API (structured output)
    ├── Queue ──► SQLite (task state)
    ├── Executor ──► AgentAdapter ──► claude (subprocess)
    ├── Verifier ──► shell commands (lint, test, tsc)
    └── Context ──► filesystem (read files, git diff)
    │
    ▼
SQLite (all persistent state)
Git (code changes, branch management)
```

### Daemon Safety

Since this runs as a permanent systemd service:
- **Memory:** Rust's ownership model prevents leaks. No GC pauses. Bounded buffers for log capture (ring buffer, configurable size). SQLite WAL mode for write performance without unbounded growth.
- **Crash recovery:** On startup, check for tasks with status `executing` — these were interrupted. Mark as `interrupted`, optionally re-queue based on config. PID file prevents double-start.
- **Resource limits:** systemd unit sets `MemoryMax=`, `CPUQuota=`, `TasksMax=`. Daemon monitors its own RSS and pauses the queue if approaching limits.
- **Graceful shutdown:** SIGTERM handler finishes current task (with timeout), persists state, closes DB cleanly. SIGKILL is safe because SQLite WAL handles incomplete writes.
- **Watchdog:** systemd `WatchdogSec=` with periodic `sd_notify` heartbeats. If daemon hangs, systemd restarts it automatically.
- **Log rotation:** tracing-appender with rolling file output + logrotate config.
