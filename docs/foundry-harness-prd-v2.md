# Sub-PRD: Foundry Harness — Agent Orchestration Engine (Bottom-Up)

> **Parent:** Foundry Workspace PRD
> **Author:** Boss / Growgami
> **Date:** March 2026
> **Status:** Draft v2 — restructured bottom-up

---

## Context

### Customer Messaging

Stop being the glue between your AI agent and your codebase. Foundry Harness is the orchestration engine that turns a single Claude Code session into a reliable, multi-step development pipeline — with task decomposition, context engineering, verification, retries, and persistent state across every session.

### Problem

The harness solves three specific technical problems that exist between "I have a capable AI coding agent" and "I can trust it to complete multi-step work reliably."

**Problem 1: The context window cliff.** Claude Code operates within a finite context window. On a complex feature with 12 sub-tasks, the agent hits context limits around task 7-8. Everything it learned — architectural decisions, failed approaches, intermediate state — is lost. The developer manually reconstructs context for a new session. Anthropic's own research shows that for long-running tasks, the solution is a two-agent pattern where progress files and git history bridge sessions. But someone has to manage that bridge. Currently, that someone is you.

**Problem 2: No verification loop.** When Claude Code completes an edit, it declares success based on its own assessment. It doesn't run the linter. It doesn't run the test suite. It doesn't typecheck. If it does run tests (via Superpowers or manual prompting), it interprets the output itself — which means it can miss failures or misunderstand errors. Stripe's Minions architecture proves that external verification (CI running outside the agent's context, with hard pass/fail signals fed back) is what makes agent output production-grade. The harness must own verification, not delegate it to the agent's self-assessment.

**Problem 3: No structured retry.** When a task fails, the developer reads the error, decides whether to retry, figures out what additional context would help, and manually constructs a better prompt. This is harness work that should be automated. The research shows clear patterns: feed the error output back as context, cap retries at 2-3 (diminishing returns after that, per Stripe's findings), and escalate to human with full diagnostic context when retries are exhausted.

### Solution

Foundry Harness is built **bottom-up in four layers**, each delivering standalone value:

```
Layer 3: Daemon + UIs         ← Rust daemon, web UI, TUI, full lifecycle
Layer 2: CLI Orchestrator     ← Multi-task plans, dependency ordering, queue
Layer 1: Session Wrapper      ← External verification, retry, state tracking
Layer 0: Claude Code Core     ← Hooks, skills, commands, plugins inside Claude Code
```

**Layer 0** makes Claude Code itself better — structured workflows, progress tracking, context bridging, and disciplined development practices enforced from inside the agent session. This layer costs nothing to deploy, requires no external infrastructure, and delivers value from day one.

**Layer 1** wraps Claude Code sessions with external verification, retry logic, and state persistence. A lightweight CLI tool (Node.js or shell) that invokes Claude Code, runs checks after it finishes, retries on failure, and logs results. Still single-task, but now with a verification loop the agent can't circumvent.

**Layer 2** adds multi-task orchestration — decomposition, dependency ordering, sequential execution, plan approval. Builds on Layer 1's verified single-task execution by sequencing multiple tasks with cross-task context bridging.

**Layer 3** is the full Foundry daemon — a Rust systemd service with HTTP API, WebSocket streaming, web UI, and TUI. It takes everything from Layers 0-2 and wraps it in production-grade infrastructure: persistent state in SQLite, resource monitoring, parallel execution, crash recovery.

Each layer is independently useful. Layer 0 alone improves every Claude Code session. Layer 0 + Layer 1 gives you verified, retried single-task execution. Layer 0 + 1 + 2 gives you multi-task plans. The full stack gives you the always-on daemon with UIs.

### Design Principles

1. **The system runs the model, not the reverse.** (Stripe's blueprint pattern.) The harness controls the loop — what task, what context, what tools, what verification, when to stop. The agent controls only the "think about code and edit files" step within that loop.

2. **Tasks are one-shot and stateless.** (Stripe Minions.) Each agent invocation gets a fresh session with assembled context. No reliance on agent memory between tasks. The harness is the memory.

3. **File-system-as-state.** (Anthropic's long-running agent pattern.) Progress is persisted to files (progress logs, git commits, structured task state) — not held in any agent's context window. Every new session reads state from the filesystem, never from a prior conversation.

4. **External verification is non-negotiable.** (Stripe's multi-layer CI.) The harness runs lint, tests, and typechecks outside the agent's process. The agent's opinion about whether code works is irrelevant — only external verification results matter.

5. **Context engineering is the primary cost and quality lever.** (Manus's 10x cost reduction, Aider's PageRank repo map, JetBrains' observation masking research.) What you put in the prompt is more important than which model you use. The harness must be excellent at assembling focused, relevant, minimal context for each task.

### Prior Art Applied

| Component | Primary Influence | Key Lesson |
|---|---|---|
| Inner workflow (Layer 0) | Superpowers (obra), Anthropic skills system | Skills as injectable methodology; brainstorm → plan → implement cycle |
| Verification hooks (Layer 0-1) | Stripe Minions | External CI, multi-layer checks, cap at 2 CI rounds |
| Context bridging (Layer 0-1) | Anthropic long-running agents | Progress files + git history; JSON for structured state |
| Session wrapper (Layer 1) | OpenAI Codex CLI | Stateless requests, structured output capture |
| Retry with enrichment (Layer 1) | Factory AI Droid | Feed failure artifacts back as context; leave breadcrumbs |
| Task decomposition (Layer 2) | Factory AI (delegator/executor split) | The planner never executes; the executor never plans |
| Context assembly (Layer 2-3) | Aider (PageRank repo map), Manus (KV-cache opt) | Focused context beats full context; stable prefixes reduce cost |
| Daemon architecture (Layer 3) | Stripe Minions (devbox), Replit Agent (Mastra + Inngest) | Durable execution, resource isolation, crash recovery |

---

## Usage Scenarios

### Scenario 1: Layer 0 — Claude Code is more disciplined out of the box

Klyde starts a Claude Code session to add rate limiting to his Express API. Because Foundry's Layer 0 skills and hooks are installed, the session behaves differently from stock Claude Code.

On session start, the `session-start` hook fires. It reads the project's `foundry.json` (if present) and injects relevant context — the project's verification preset (node-typescript), any active plan context, and the Foundry methodology instructions. Claude Code now knows: always run verification before declaring done, write progress to `foundry-progress.json` after completing a logical chunk, commit incrementally with descriptive messages.

Klyde types: "Add rate limiting middleware." Instead of diving into code, the Foundry `/plan` skill activates. Claude Code asks two clarifying questions about the scope, writes a mini-plan to `.foundry/plans/rate-limiter.md`, and asks Klyde to approve. Klyde says "go." Claude Code implements step by step, running `npm run lint` and `npm run test` via the `/verify` command after each significant change. The `post-tool-use` hook captures every tool invocation and appends to `.foundry/session-log.jsonl` for later analysis.

When Claude Code finishes, the `pre-commit` hook runs the full verification preset. If lint or tests fail, the hook blocks the commit and surfaces the errors. Claude Code sees the hook output and fixes the issues before committing.

No external tooling ran. No daemon was involved. Claude Code was just better — because Layer 0 gave it structure, verification checkpoints, and progress tracking inside the session.

### Scenario 2: Layer 1 — Verified, retried single-task execution

Klyde has a task he wants to fire-and-forget: migrate a Supabase table schema and update all queries that reference it. He doesn't trust a single Claude Code session to get this right without external verification.

He runs:
```bash
foundry exec --task "Migrate the users table: add 'role' column (enum: admin, member, viewer, default member), update all Supabase queries in src/db/ to include role, add a migration file in supabase/migrations/" --verify node-typescript --retries 2
```

The Layer 1 CLI wrapper:
1. Launches Claude Code with the task prompt + relevant context (auto-detected from file paths in the task description)
2. Claude Code runs with Layer 0 skills active (structured workflow, progress tracking)
3. When Claude Code exits, the wrapper runs external verification: `npm run lint` → `npx tsc --noEmit` → `npm run test`
4. Tests fail — the migration file has a syntax error in the SQL
5. The wrapper captures the error, assembles a retry prompt ("Previous attempt failed: test output shows SQL syntax error in supabase/migrations/20260316_add_role.sql, line 12"), and launches a new Claude Code session with this enriched context
6. Second attempt passes all verification
7. The wrapper commits, logs the execution (2 attempts, total duration, token usage), and exits

Klyde has a verified result. He didn't watch either session. The wrapper handled the retry loop.

### Scenario 3: Layer 2 — Multi-task plan with dependency ordering

Klyde has the Prometheus trend analysis pipeline to build — 8 interconnected features. He runs:

```bash
foundry decompose --prd docs/prometheus-ms2.md --project /home/boss/projects/prometheus
```

The CLI calls the Anthropic API directly (Sonnet, structured output) and produces a proposed plan:

```
Plan: Implement trend analysis pipeline (8 tasks)

  [1] Create TrendAnalyzer service scaffold          → no deps         [small]
  [2] Implement TikTok data fetching adapter          → no deps         [medium]
  [3] Add Redis Streams consumer for trend events     → no deps         [medium]
  [4] Implement trend scoring algorithm               → after [1,2]     [large]
  [5] Add trend persistence to Supabase               → after [1,2]     [medium]
  [6] Wire scoring into consumer pipeline             → after [3,4,5]   [medium]
  [7] Add integration tests for full pipeline         → after [6]       [large]
  [8] Add trend analysis endpoint to API              → after [5,7]     [small]

Save plan? [y]es / [e]dit / [r]egenerate:
```

Klyde edits task 5's dependencies and approves. The orchestrator creates a feature branch and begins sequential execution — each task going through Layer 1's verified execution loop. Between tasks, the orchestrator updates `foundry-progress.json` so each subsequent task knows what was already built.

Task 7 fails after 2 retries. The orchestrator marks it as `failed_needs_human`, reports the status, and stops (task 8 depends on 7). All completed work is committed to the feature branch. Klyde fixes the integration test issue manually, tells the orchestrator to continue (`foundry plan resume plan-003`), and task 8 executes successfully.

### Scenario 4: Layer 3 — The daemon runs while Klyde is AFK

Same scenario as above, but now Foundry is running as a systemd daemon. Klyde submits the plan via the web UI, approves it, and closes his laptop. The daemon processes the queue overnight. By morning, the Foundry web UI shows 7/8 tasks complete, 1 failed with full diagnostic logs. Klyde reviews from his phone, adds a hint to the failed task, hits retry, and it passes. He merges the branch from the web UI.

---

## Milestones

### MS-H0: Claude Code Enhancement Layer ("Make the agent smarter")

**Goal:** A comprehensive set of hooks, skills, rules, commands, subagents, and plugins for Claude Code that enforce structured workflows, progress tracking, continuous verification, context management, and cross-session handoff — all from inside the agent session. This layer delivers value immediately with zero external infrastructure.

**Delivery:** A Foundry plugin for Claude Code (published to the plugin marketplace and installable from git). All functionality lives inside Claude Code's extension system.

**Key design principle: token-light core, lazy-load everything.** The bootstrap injects <2K tokens. Skills are loaded on demand via shell script search (the Superpowers pattern). Rules are always-active but concise. Total steady-state context cost of Foundry Layer 0 should be under 5K tokens.

#### 0.1 Session Lifecycle Hooks

Claude Code hooks fire at specific points in the agent's lifecycle. Foundry uses all six hook types to inject behavior without modifying Claude Code itself.

- **`UserPromptSubmit` hook — Session initialization:**
  - On first prompt only (guard via `.foundry/.session-initialized` flag):
    - Read `foundry.json` from the project root for project-specific config
    - Read `.foundry/active-plan.json` to inject active plan context (if present)
    - Read `foundry-progress.json` for cross-session continuity (if present)
    - Read `.foundry/handoff-note.md` for instructions from the previous session (if present)
    - Set up the `.foundry/` directory structure if missing
    - Run context budget check: count active MCP tools, warn if >80 active tools (context window pressure)
    - Inject Foundry methodology via the bootstrap skill pointer (same pattern as Superpowers: "You have Foundry. RIGHT NOW, go read: .foundry/skills/getting-started/SKILL.md")

- **`PostToolUse` hooks — Continuous verification & observability:**

  - **Auto-typecheck after file edits** (the most impactful single hook):
    ```json
    {
      "matcher": "tool == 'Edit' && tool_input.file_path matches '\\.(ts|tsx)$'",
      "hooks": [{
        "type": "command",
        "command": "npx tsc --noEmit --pretty 2>&1 | head -20 || true"
      }]
    }
    ```
    This catches type errors immediately after each edit, before they compound across files. The agent sees the error inline and fixes it in the same turn instead of discovering a cascade 10 edits later. Configurable: can be swapped for `ruff check` (Python), `cargo check` (Rust), etc. via `foundry.json`.

  - **Auto-format after file edits:**
    ```json
    {
      "matcher": "tool == 'Edit' && tool_input.file_path matches '\\.(ts|tsx|js|jsx)$'",
      "hooks": [{
        "type": "command",
        "command": "npx prettier --write \"$TOOL_INPUT_FILE_PATH\" 2>/dev/null || true"
      }]
    }
    ```

  - **Change tracking & verification reminders:**
    - After `Edit` / `Write` tool calls: increment a change counter in `.foundry/.change-count`
    - After every N changes (configurable, default 5): emit a stderr reminder: `[Foundry] ${N} files changed since last checkpoint. Run /foundry:checkpoint or /foundry:verify.`

  - **Tool call logging:**
    - Log every tool invocation to `.foundry/session-log.jsonl`: tool name, arguments summary, timestamp, duration
    - This is the observability layer that Layer 1+ consumes for execution analysis

  - **Quality gates:**
    ```json
    {
      "matcher": "tool == 'Edit'",
      "hooks": [{
        "type": "command",
        "command": "grep -n 'console\\.log' \"$TOOL_INPUT_FILE_PATH\" | head -5 && echo '[Foundry] ⚠ console.log detected — remove before commit' >&2 || true"
      }]
    }
    ```
    Additional quality gate patterns (configurable):
    - Warn on files exceeding 300 lines after edit
    - Warn on TODO/FIXME without issue reference
    - Block `debugger` statements in JS/TS files
    - Warn on hardcoded strings that look like secrets (basic pattern matching)

- **`PreToolUse` hooks — Prevention & scope enforcement:**

  - **Block unnecessary file creation:**
    ```json
    {
      "matcher": "tool == 'Write' && tool_input.file_path matches '\\.md$' && !(tool_input.file_path matches '(README|CLAUDE|CHANGELOG|foundry)')",
      "hooks": [{
        "type": "command",
        "command": "echo '[Foundry] ⚠ Creating .md file outside README/CLAUDE/CHANGELOG. Is this needed?' >&2"
      }]
    }
    ```

  - **tmux reminder for long-running commands:**
    ```json
    {
      "matcher": "tool == 'Bash' && tool_input.command matches '(npm run|pnpm|yarn|cargo build|pytest|docker)'",
      "hooks": [{
        "type": "command",
        "command": "if [ -z \"$TMUX\" ]; then echo '[Foundry] Consider tmux for session persistence with long-running commands' >&2; fi"
      }]
    }
    ```

  - **Scope enforcement (when in a plan):**
    - If `.foundry/active-plan.json` exists with a `current_task.relevant_files` list, warn when the agent tries to edit files outside that scope:
    ```json
    {
      "matcher": "tool == 'Edit'",
      "hooks": [{
        "type": "command",
        "command": ".foundry/scripts/check-scope.sh \"$TOOL_INPUT_FILE_PATH\""
      }]
    }
    ```

- **`Stop` hook — Session end audit:**
  - Audit all modified files for `console.log`, `debugger`, uncommitted changes
  - If there's an active plan, check if the current task's acceptance criteria are met
  - Remind to run `/foundry:handoff` if context usage is >70% and work remains
  - Log session summary to `.foundry/session-log.jsonl`: total tool calls, files changed, verification results, duration

- **`PreCompact` hook — Context preservation:**
  - Before Claude Code compacts the context window, automatically run `/foundry:checkpoint`:
    - Commit current work in progress
    - Update `foundry-progress.json` with current state
    - Write `.foundry/handoff-note.md` with context that must survive compaction
  - This prevents losing architectural decisions and intermediate state when compaction triggers

- **`Notification` hook — Desktop alerts:**
  - On task completion: `notify-send "Foundry" "Task complete: <summary>"`
  - On verification failure: `notify-send -u critical "Foundry" "Verification failed: <error>"`
  - On plan milestone: `notify-send "Foundry" "Plan progress: 5/8 tasks complete"`

**Hook configuration (`.foundry/hooks.toml`):**
```toml
[session-start]
inject_progress = true
inject_methodology = true
inject_plan_context = true
context_budget_warning_threshold = 80  # warn if active tools exceed this

[post-tool-use]
continuous_typecheck = true            # tsc --noEmit after every .ts edit
continuous_format = true               # prettier after every .ts/.js edit
track_changes = true
change_checkpoint_interval = 5         # remind to checkpoint every N file changes
log_tool_calls = true

[post-tool-use.quality-gates]
warn_console_log = true
warn_debugger = true
warn_file_too_long = 300               # lines threshold, 0 to disable
warn_todo_without_issue = true
warn_hardcoded_secrets = true

[pre-tool-use]
block_unnecessary_md = true
tmux_reminder = true
enforce_task_scope = true              # warn on out-of-scope file edits during plan execution

[pre-commit]
mode = "strict"                        # strict | warn | skip
verification_preset = "node-typescript"

[pre-compact]
auto_checkpoint = true                 # checkpoint before compaction
auto_handoff = true                    # write handoff note before compaction

[stop]
audit_modified_files = true
check_acceptance_criteria = true
remind_handoff = true
evaluate_session_learnings = true     # extract reusable knowledge at session end

[stop.continuous-learning]
enabled = true                         # analyze session for extractable patterns
output_dir = ".foundry/learned"        # save learned skills here
min_session_turns = 10                 # don't evaluate trivially short sessions
categories = ["error-resolution", "workaround", "pattern", "debugging-technique"]

[notification]
enabled = true
on_complete = true
on_failure = true
on_plan_milestone = true

[compaction]
strategy = "manual"                    # manual | auto | foundry-managed
tool_call_threshold = 50               # suggest compaction after N tool calls
suggest_on_phase_transition = true     # suggest when switching from exploration to execution
```

#### 0.2 Foundry Rules (Always-Active Constraints)

Rules are `.md` files in `.foundry/rules/` that are always injected into context. Unlike skills (loaded on demand), rules are constraints the agent must follow at all times. Rules are concise — each under 500 tokens — because they burn context permanently.

**Directory structure:**
```
.foundry/rules/
├── workflow.md          # Always update progress file after completing a task
│                        # Always commit incrementally with conventional commit format
│                        # Never declare "done" without running verification
│                        # If a plan is active, follow the plan task order
│
├── scope.md             # Never modify files outside the current task scope
│                        # Never add dependencies without documenting the reason
│                        # Never refactor code unrelated to the current task
│                        # If you discover a bug outside scope, log it to .foundry/found-issues.md
│
├── quality.md           # No console.log in committed code
│                        # No hardcoded secrets, API keys, or tokens
│                        # No files exceeding 300 lines without justification
│                        # No commented-out code blocks — delete or keep
│
├── context.md           # Read foundry-progress.json before starting work
│                        # Read .foundry/handoff-note.md if it exists
│                        # Append important architectural decisions to the progress file
│                        # Before reading a file, check the codemap first
│
└── git.md               # Use conventional commits: feat:, fix:, refactor:, test:, docs:
                         # Commit after each logical unit, not at the end
                         # Never force push
                         # Include [foundry:<task-id>] in commit message when in a plan
```

Rules are loaded at session start and occupy a fixed context budget. The total rules payload should not exceed 2K tokens. If project-specific rules are needed, they go in the project's `foundry.json` under a `rules` key, not as additional files.

#### 0.3 Foundry Skills (On-Demand Workflows)

Skills are markdown instruction files loaded only when invoked. They encode methodology — the "how to work" knowledge that makes sessions more reliable. Each skill has a `SKILL.md` with trigger conditions, instructions, and a script for the skill search index.

**Skill directory structure:**
```
.foundry/skills/
├── getting-started/
│   └── SKILL.md            # Bootstrap — loaded once per session, teaches skill system
├── plan/
│   └── SKILL.md            # Structured planning before implementation
├── verify/
│   └── SKILL.md            # Run verification and interpret results
├── progress/
│   └── SKILL.md            # Cross-session state management
├── checkpoint/
│   └── SKILL.md            # Atomic save points
├── context/
│   └── SKILL.md            # Smart context loading
├── codemap/
│   ├── SKILL.md            # Generate and maintain codebase map
│   └── generate-codemap.sh # Script to produce codemap from file tree + exports
├── handoff/
│   └── SKILL.md            # Prepare for session end
├── parallel/
│   └── SKILL.md            # Set up forked conversations for independent subtasks
├── learn/
│   ├── SKILL.md            # Extract reusable knowledge from current session
│   └── evaluate-session.sh # Script to analyze session for extractable patterns
├── compact/
│   └── SKILL.md            # Strategic context compaction at logical boundaries
└── benchmark/
    └── SKILL.md            # A/B compare task execution with/without Foundry skills
```

**Skill search:** a shell script (`.foundry/scripts/search-skills.sh`) that greps skill names and descriptions, returning the path to the relevant SKILL.md. The bootstrap skill teaches the agent to run this script when it encounters a situation that might have a matching skill. This keeps the token cost near-zero when skills aren't active.

**Skill definitions:**

- **`/foundry:plan`** — Structured planning before implementation:
  - Trigger: automatically on complex tasks (multi-file changes, new features), or via command
  - Stop coding, write a plan to `.foundry/plans/<slug>.md`
  - Plan format: objective, task breakdown with dependency order, target files per task, acceptance criteria per task, estimated complexity per task
  - Ask the user to approve before proceeding
  - If a plan already exists for the current session, read and follow it
  - Update `foundry-progress.json` as plan tasks complete
  - If the task is simple (single file fix, small change), skip planning — don't force overhead on trivial work

- **`/foundry:verify`** — Run verification and interpret results:
  - Read verification preset from `foundry.json`
  - Run each command in order, capture structured pass/fail
  - On failure: identify the specific error (file, line, message) and fix it
  - On all-pass: confirm and suggest committing via `/foundry:checkpoint`
  - Distinguish between required checks (must pass) and advisory checks (warn only)

- **`/foundry:progress`** — Cross-session state management:
  - Read `foundry-progress.json` at session start
  - Write/update after completing a logical chunk of work
  - Progress file format (JSON — less likely to be inappropriately modified by the model):
    ```json
    {
      "project": "prometheus",
      "plan": "trend-analysis-pipeline",
      "last_updated": "2026-03-16T22:30:00Z",
      "session_count": 3,
      "completed": [
        {
          "task": "Create TrendAnalyzer scaffold",
          "files_changed": ["src/services/trend-analyzer.ts"],
          "commit": "abc1234",
          "summary": "Created TrendAnalyzer class with score(), analyze(), persist() stubs"
        }
      ],
      "current_task": "Implement trend scoring algorithm",
      "remaining": ["Wire scoring into pipeline", "Integration tests", "API endpoint"],
      "decisions": [
        "Using weighted moving average for trend scoring (discussed in session 2)",
        "Redis Streams consumer group: 'trend-processor' (set up in session 1)"
      ],
      "blocked": [],
      "found_issues": [
        "Potential race condition in Redis consumer acknowledged — will address in task 6"
      ],
      "failed_approaches": [
        {
          "task": "Integration tests for pipeline",
          "approach": "Attempted to mock Redis Streams with ioredis-mock",
          "error": "TypeError: mock.xadd is not a function — ioredis-mock lacks Streams support",
          "session": 3
        }
      ]
    }
    ```
  - The `decisions` array captures architectural choices that must persist across context windows
  - The `failed_approaches` array is critical for retry efficiency — it records what was tried and why it failed, so the next session (or Layer 1's retry engine) doesn't repeat dead-end approaches. Each entry includes the approach description, the specific error, and which session it occurred in.
  - The `found_issues` array captures bugs/issues discovered outside current task scope (from the scope rule: "log it, don't fix it now")

- **`/foundry:checkpoint`** — Atomic save points:
  - Run verification (if `auto_verify_on_checkpoint` is true in config)
  - Commit current work with a descriptive conventional commit message
  - Update the progress file with what was accomplished
  - Update the codemap if file structure changed (new files, moved files, deleted files)
  - Tag the commit with the current task ID if in a plan
  - Designed to be called frequently — after each logical unit, not just at session end

- **`/foundry:codemap`** — Codebase navigation map:
  - Generate/update `.foundry/codemap.md` — a structured overview of the codebase that the agent reads instead of exploring files manually
  - Generation script (`.foundry/scripts/generate-codemap.sh`) produces:
    - File tree (depth 3, excluding node_modules/dist/.git)
    - For each key source file: exported symbols (functions, classes, types, constants) via lightweight AST parsing (tree-sitter or grep-based)
    - Entry points (main, index files)
    - Config files and their purpose
    - Recent git activity (most-changed files in last 20 commits)
  - The codemap is a navigational index, not full file contents — typically 1-3K tokens for a medium project
  - Updated at checkpoints (when file structure changes) and at session start (if stale >1 hour)
  - Inspired by Aider's PageRank repo map but lighter — no graph analysis, just structured metadata that helps the agent find the right files without reading everything
  - The `context.md` rule instructs the agent: "Before reading a file, check the codemap first"

- **`/foundry:context`** — Smart context loading:
  - When starting a task, identify which files the agent needs to read
  - Read the codemap first for navigation
  - Follow import/require statements from target files, one level deep
  - Read `foundry-progress.json` for decisions and patterns from previous sessions
  - Read git log for recent changes to relevant files
  - Estimate token cost of proposed context and warn if it exceeds 40% of remaining window
  - Output a structured context summary the agent can reference without re-reading files

- **`/foundry:handoff`** — Prepare for session end:
  - Commit any uncommitted work
  - Update `foundry-progress.json` with what was accomplished, what remains, key decisions made
  - Write `.foundry/handoff-note.md` with natural-language instructions for the next session:
    - What was the task and what's the status
    - What files were changed and why
    - What approaches were tried that didn't work (prevents the next session from repeating failures)
    - What the next session should do first
  - The next session's startup hook reads this handoff note automatically

- **`/foundry:parallel`** — Set up parallel work:
  - For plans with independent tasks, help the user set up parallel Claude Code sessions
  - Create git worktrees for each independent task: `git worktree add ../<project>-task-<id> -b foundry/task-<id>`
  - Output instructions for launching separate Claude Code sessions in each worktree
  - This is a manual parallel pattern for Layer 0 — Layer 3's daemon automates this

- **`/foundry:learn`** — Extract reusable knowledge from the current session:
  - Can be invoked mid-session when a non-trivial problem was just solved, or runs automatically via `Stop` hook at session end
  - Analyzes the session for patterns worth persisting: error resolutions, debugging techniques, workarounds, project-specific patterns, API quirks, library gotchas
  - For each extracted pattern, creates a lightweight skill snippet in `.foundry/learned/`:
    ```
    .foundry/learned/
    ├── redis-streams-mock-limitation.md    # ioredis-mock lacks xadd — use testcontainers instead
    ├── supabase-rls-debugging.md           # RLS policies silently return empty — check with service role key first
    └── nextjs-middleware-matcher.md        # matcher config must be static — no runtime evaluation
    ```
  - Each learned skill has: trigger condition (when to load this), the problem, what didn't work, what worked, and code example if applicable
  - Learned skills are indexed by the skill search script and loaded when a similar problem arises in future sessions
  - The `Stop` hook version (`evaluate-session.sh`) scans the session log for: repeated error patterns, corrections the user made, tool call sequences that suggest debugging, and prompts where the user had to re-steer the agent. It extracts these as candidates and either auto-saves (if confidence is high) or appends to `.foundry/learn-candidates.md` for user review
  - The compound effect: every session makes future sessions better. After a month, the `.foundry/learned/` directory is a project-specific knowledge base that eliminates the most common friction points

- **`/foundry:compact`** — Strategic context compaction at logical boundaries:
  - Replaces auto-compaction with intentional compaction at phase transitions
  - When invoked: run `/foundry:checkpoint` first (save all progress), then trigger `/compact`
  - The skill instructs when to compact:
    - After exploration/research phase, before implementation
    - After completing a plan milestone, before starting the next
    - When context usage exceeds 70% and the current task is at a natural boundary
    - After a failed approach is fully documented (don't lose the failure context *before* recording it)
  - When NOT to compact: mid-implementation, while debugging an active error, before the progress file is updated
  - Works with the `PreToolUse` tool-call counter: after the configured threshold (default 50 tool calls), the hook suggests compaction. The skill provides the methodology for *how* to compact cleanly.
  - The `compaction.strategy` config option controls behavior:
    - `"auto"` — Claude Code's default auto-compaction (no Foundry intervention)
    - `"manual"` — auto-compact disabled, user triggers via `/foundry:compact`
    - `"foundry-managed"` — auto-compact disabled, Foundry suggests at logical boundaries via hook, user confirms

- **`/foundry:benchmark`** — A/B compare task execution with and without Foundry:
  - Creates two git worktrees from the same commit
  - Worktree A: Foundry Layer 0 fully active (skills, hooks, rules, subagents)
  - Worktree B: stock Claude Code (no Foundry plugin, vanilla config)
  - Both receive the same task description
  - After both complete, the skill produces a comparison report:
    - Verification pass rate (did the output pass lint/typecheck/tests?)
    - Token usage (from session logs)
    - Number of tool calls
    - Time to completion
    - Git diff size and quality (manual review — does the code follow conventions?)
    - Number of retries needed
  - Useful for validating that Foundry skills actually improve outcomes and for identifying which skills have the most impact
  - Can also benchmark different skill configurations against each other (e.g., with vs without continuous typecheck)

#### 0.4 Foundry Subagents

Subagents are scoped Claude Code instances that the main agent can delegate to. Each subagent has limited tool access and a focused instruction set. Subagent definitions live in `.foundry/agents/`.

```
.foundry/agents/
├── planner.md            # Decomposes objectives into tasks
├── verifier.md           # Runs verification, interprets results
├── reviewer.md           # Reviews changes against plan/criteria
├── context-builder.md    # Gathers relevant files, builds context summaries
└── refactorer.md         # Dead code removal, import cleanup, file organization
```

**Subagent scoping principles (from the Stripe constraint pattern):**

- **Planner** — allowed tools: file read, bash (tree, cat, grep only). No file write. No git. Its job is to think and produce a plan document, not to implement anything. The planner never executes.
- **Verifier** — allowed tools: bash (lint, test, typecheck commands only). No file read beyond test output. No file write. Its job is to run checks and return structured pass/fail results.
- **Reviewer** — allowed tools: file read, bash (grep, diff only). No file write. Reviews changes against the plan's acceptance criteria, checks for scope creep, flags potential issues. Outputs a review document with severity ratings (critical blocks progress, warning is advisory).
- **Context-builder** — allowed tools: file read, bash (tree, cat, grep, git log). No file write. Gathers relevant files for a task, builds context summaries, estimates token costs. Useful for complex tasks where the agent would otherwise burn context on exploration.
- **Refactorer** — allowed tools: file read, file write, bash (lint, format, test). Scoped to specific refactoring tasks: remove dead code, clean unused imports, enforce file size limits, reorganize exports. Only activated post-task as a cleanup pass.

**Delegation rules** (defined in `.foundry/rules/delegation.md`):
- Before implementing a complex feature (>3 files, >1 hour estimated), delegate to planner first
- After completing a task in a plan, delegate to reviewer before marking as done
- When a reviewer flags a critical issue, fix it before proceeding to the next task
- Never delegate implementation work to subagents — only planning, review, and verification

#### 0.5 Custom Commands

Claude Code slash commands that trigger Foundry functionality:

```
/foundry:plan          Activate the planning skill — write a plan before coding
/foundry:verify        Run verification preset and show results
/foundry:progress      Show/update the progress file
/foundry:checkpoint    Commit + update progress + update codemap + optionally verify
/foundry:codemap       Generate or refresh the codebase navigation map
/foundry:context       Load relevant context for the current task
/foundry:handoff       Prepare for session end (commit, progress, handoff note)
/foundry:parallel      Set up worktrees for parallel task execution
/foundry:learn         Extract reusable knowledge from this session (or run mid-session after solving something)
/foundry:compact       Strategic context compaction at a logical boundary (checkpoint first, then compact)
/foundry:benchmark     A/B compare task execution with vs without Foundry skills
/foundry:status        Current session state: what's done, in progress, remaining
/foundry:config        Show/edit Foundry project configuration
/foundry:init          Initialize Foundry in a new project (create foundry.json, .foundry/)
/foundry:review        Delegate to the reviewer subagent for current changes
/foundry:clean         Delegate to the refactorer subagent for cleanup pass
```

#### 0.6 Project Configuration (`foundry.json`)

Each project has a `foundry.json` at its root that all Layer 0 components read:

```json
{
  "project_name": "prometheus",
  "stack": "node-typescript",

  "verification": {
    "preset": "node-typescript",
    "custom_commands": [
      { "name": "db-check", "command": "npx supabase db lint", "required": false }
    ],
    "continuous": {
      "typecheck_on_edit": true,
      "format_on_edit": true,
      "typecheck_command": "npx tsc --noEmit --pretty 2>&1 | head -20",
      "format_command": "npx prettier --write"
    }
  },

  "context": {
    "always_include": ["CLAUDE.md", "docs/architecture.md"],
    "ignore_patterns": ["node_modules", "dist", ".next", "coverage", "*.test.ts"],
    "codemap_depth": 3,
    "codemap_max_tokens": 3000
  },

  "workflow": {
    "require_plan_for_complex_tasks": true,
    "auto_checkpoint_interval": 5,
    "auto_verify_on_checkpoint": true,
    "auto_review_before_plan_task_complete": true,
    "commit_convention": "conventional"
  },

  "quality_gates": {
    "warn_console_log": true,
    "warn_debugger": true,
    "warn_file_too_long": 300,
    "warn_todo_without_issue": true,
    "warn_hardcoded_secrets": true,
    "block_unnecessary_md": true
  },

  "mcps": {
    "disabled_in_project": [
      "playwright",
      "cloudflare-docs",
      "clickhouse"
    ],
    "max_active_tools_warning": 80,
    "cli_alternatives": {
      "github": {
        "mcp": "@modelcontextprotocol/server-github",
        "cli": "gh",
        "commands": {
          "create_pr": "gh pr create --title '{title}' --body '{body}'",
          "list_issues": "gh issue list --state open --json number,title,labels",
          "review_pr": "gh pr review {number} --approve"
        },
        "note": "gh CLI is pre-authed and uses zero context window vs ~15 tools from the MCP"
      },
      "supabase": {
        "mcp": "@supabase/mcp-server-supabase",
        "cli": "npx supabase",
        "commands": {
          "db_query": "npx supabase db query '{sql}'",
          "migrations": "npx supabase migration list",
          "db_lint": "npx supabase db lint"
        },
        "note": "For heavy DB operations, CLI avoids streaming large result sets through context"
      }
    }
  },

  "models": {
    "default": "sonnet",
    "complexity_routing": {
      "small": "sonnet",
      "medium": "sonnet",
      "large": "opus"
    },
    "retry_escalation": true,
    "note": "When a task fails on sonnet, retry with opus. Layer 1/2 pass --model to claude CLI."
  },

  "learning": {
    "enabled": true,
    "auto_evaluate_on_stop": true,
    "learned_dir": ".foundry/learned",
    "min_session_turns": 10,
    "auto_save_confidence_threshold": 0.8,
    "candidates_file": ".foundry/learn-candidates.md"
  },

  "compaction": {
    "strategy": "foundry-managed",
    "tool_call_threshold": 50,
    "context_usage_warning": 70
  },

  "foundry": {
    "progress_file": "foundry-progress.json",
    "plans_dir": ".foundry/plans",
    "session_logs_dir": ".foundry/logs",
    "codemap_file": ".foundry/codemap.md",
    "rules_dir": ".foundry/rules",
    "agents_dir": ".foundry/agents",
    "learned_dir": ".foundry/learned"
  }
}
```

#### 0.7 Plugin Packaging & Installation

**Marketplace installation (primary path):**
```bash
# Register the Foundry marketplace
/plugin marketplace add growgami/foundry-marketplace

# Install the plugin
/plugin install foundry@foundry-marketplace
```

**Git installation (fallback):**
```bash
# Clone and symlink
git clone https://github.com/growgami/foundry-claude-plugin ~/.foundry-plugin
ln -s ~/.foundry-plugin/skills ~/.claude/skills/foundry
```

**Bootstrap mechanism (session-start hook injection):**
```
<session-start-hook>
<IMPORTANT>
You have Foundry installed. RIGHT NOW, go read:
~/.claude/plugins/cache/Foundry/skills/getting-started/SKILL.md
</IMPORTANT>
</session-start-hook>
```

The getting-started skill teaches Claude:
- You have Foundry skills. Search for them with `.foundry/scripts/search-skills.sh`.
- You have Foundry rules. They are always active. Read `.foundry/rules/` to know your constraints.
- You have Foundry subagents. Delegate to them per the delegation rules.
- If you have a skill for a workflow, you MUST use it.
- Start every session by reading `foundry-progress.json` and `.foundry/handoff-note.md` if they exist.

**Compatibility:**
- **With Superpowers:** complementary, not conflicting. Superpowers handles TDD workflow, debugging methodology, and inner code review. Foundry handles session lifecycle, progress tracking, cross-session state, verification infrastructure, and planning workflow. If both installed, Foundry defers to Superpowers for TDD-specific skills and Superpowers defers to Foundry for session management. Document the integration in getting-started skill.
- **With Codex:** install via Codex's plugin mechanism. Fetch and follow instructions from the repo's `.codex/INSTALL.md`.
- **With OpenCode:** similar alternate install path documented in `.opencode/INSTALL.md`.

#### 0.8 Directory Structure Summary

After `foundry init`, a project has:

```
project-root/
├── foundry.json                    # Project configuration (checked into git)
├── foundry-progress.json           # Cross-session state (gitignored or checked in — user choice)
├── CLAUDE.md                       # Existing Claude Code project instructions
├── .foundry/
│   ├── rules/                      # Always-active constraints
│   │   ├── workflow.md
│   │   ├── scope.md
│   │   ├── quality.md
│   │   ├── context.md
│   │   ├── git.md
│   │   └── delegation.md
│   ├── skills/                     # On-demand workflow definitions
│   │   ├── getting-started/
│   │   ├── plan/
│   │   ├── verify/
│   │   ├── progress/
│   │   ├── checkpoint/
│   │   ├── codemap/
│   │   ├── context/
│   │   ├── handoff/
│   │   └── parallel/
│   ├── agents/                     # Subagent definitions
│   │   ├── planner.md
│   │   ├── verifier.md
│   │   ├── reviewer.md
│   │   ├── context-builder.md
│   │   └── refactorer.md
│   ├── scripts/                    # Helper scripts for skills and hooks
│   │   ├── search-skills.sh
│   │   ├── generate-codemap.sh
│   │   ├── check-scope.sh
│   │   └── check-quality.sh
│   ├── plans/                      # Plan files (created by /foundry:plan)
│   ├── logs/                       # Session logs (gitignored)
│   ├── hooks.toml                  # Hook configuration
│   ├── codemap.md                  # Generated codebase navigation map
│   ├── handoff-note.md             # Last session's handoff (overwritten each session)
│   ├── found-issues.md             # Issues discovered outside task scope
│   ├── learn-candidates.md         # Patterns pending user review for extraction
│   ├── learned/                    # Extracted reusable knowledge (grows over time)
│   │   ├── redis-streams-mock.md   # Example: learned from session 3
│   │   └── supabase-rls-debug.md   # Example: learned from session 5
│   └── .session-initialized        # Guard flag for single-run init (gitignored)
├── .gitignore                      # Updated by foundry init to ignore session artifacts
└── src/
    └── ...
```

**`.gitignore` additions by `foundry init`:**
```
# Foundry session artifacts
.foundry/logs/
.foundry/.session-initialized
.foundry/.change-count
.foundry/learn-candidates.md
```

**Checked into git (shared with team if applicable):**
`foundry.json`, `.foundry/rules/`, `.foundry/skills/`, `.foundry/agents/`, `.foundry/scripts/`, `.foundry/hooks.toml`, `.foundry/learned/` (project-specific knowledge base — valuable for the whole team)

**User choice (gitignored or checked in):**
`foundry-progress.json`, `.foundry/codemap.md`, `.foundry/plans/`, `.foundry/found-issues.md`, `.foundry/handoff-note.md`

**Out of scope for MS-H0:** Any external process, daemon, CLI wrapper, or UI. Everything runs inside Claude Code's session.

**De-risk:**
1. **Hook reliability** — do all six Claude Code hook types (`UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`, `PreCompact`, `Notification`) fire consistently? Are `PostToolUse` hooks called for every tool invocation, or can they be skipped under load? Test with various tool types (file edit, bash, MCP tool calls) and measure hook execution time (must be <1s to avoid slowing the agent).
2. **Continuous typecheck performance** — running `tsc --noEmit` after every `.ts` edit could be slow on large projects. Measure on Prometheus codebase. If >3s, switch to incremental typecheck (`tsc --noEmit --incremental`) or scope to changed files only. May need a fast-path that only checks the edited file's imports.
3. **Skill adoption under pressure** — will Claude Code consistently follow skills and rules, or skip them when the task is complex and context is tight? The Superpowers approach ("you MUST use this skill") combined with strong language in rules helps, but needs empirical testing across 10+ real sessions. If adoption is inconsistent, consider making critical behaviors hook-enforced (external) rather than skill-enforced (agent-dependent).
4. **Subagent scoping** — do tool permission restrictions on subagents actually hold, or can a subagent break out of its scope? Test each subagent with adversarial prompts that request out-of-scope actions.
5. **Progress file fidelity** — will the agent correctly update `foundry-progress.json` with accurate summaries and decisions, or hallucinate/omit? Consider a `PostToolUse` hook on `Write` that validates the progress file schema after any write to it.
6. **Compatibility with Superpowers** — if both plugins are installed, do they conflict? Test: skill activation order, hook priority, overlapping methodology instructions. Document which plugin owns which workflow.
7. **Context budget** — measure total token cost of Foundry Layer 0 at steady state. Target: <5K tokens for rules + bootstrap. If codemap is regenerated mid-session, it should replace the old one in context, not append. Verify this works with Claude Code's context management.
8. **Codemap accuracy** — does the lightweight AST parsing (grep/tree-sitter based) produce useful export listings, or is it too noisy for large projects? Test on 3+ real codebases of varying size. May need language-specific codemap generators.

---

### MS-H1: Session Wrapper ("Verified execution from outside")

**Goal:** A CLI tool that wraps Claude Code sessions with external verification, retry logic, and execution logging. This is the first layer that runs *outside* the agent — it doesn't trust the agent's self-assessment and enforces verification independently.

**Dependency:** MS-H0 installed in Claude Code (the wrapper benefits from Layer 0's progress tracking and structured output, but can function without it in degraded mode).

**Delivery:** A CLI tool — initially a Node.js/TypeScript script (matching your core stack for fast iteration), with a path to rewrite as a Rust binary when it stabilizes.

#### 1.1 Core Execution Loop

The wrapper implements a single-task execution cycle:

```
receive task → assemble context → invoke claude code → capture output 
    → run external verification → [pass: commit + log] / [fail: retry or escalate]
```

- **Task input:** JSON file or inline string describing the task. Schema:
  ```json
  {
    "description": "Task description",
    "working_dir": "/path/to/project",
    "relevant_files": ["src/foo.ts", "src/bar.ts"],
    "verification_preset": "node-typescript",
    "acceptance_criteria": ["criterion 1", "criterion 2"],
    "max_retries": 2,
    "timeout_seconds": 900,
    "agent": "claude-code",
    "model_hint": "sonnet",
    "execution_mode": "direct"
  }
  ```
  - `model_hint`: `"sonnet"` (default), `"opus"` (complex/architectural tasks), or `"haiku"` (simple/repetitive). Passed to Claude Code as `--model`. On retry failure with sonnet, auto-escalates to opus if `retry_escalation` is enabled in `foundry.json`.
  - `execution_mode`: `"direct"` (default — invoke agent, verify, done) or `"phased"` (research → plan → implement → review → verify using subagents for each phase). Phased mode is heavier but more reliable for complex tasks spanning 5+ files.

- **Context assembly — two-tier prompt structure:**
  The wrapper splits context into two tiers based on instruction authority:

  - **System prompt** (highest authority, via `--system-prompt`): task description, acceptance criteria, constraints, scope restrictions, and any Foundry rules that are critical for this task. System-level content is weighted higher in Claude's instruction hierarchy than tool output or user messages.
  - **Piped context** (regular authority, via stdin): relevant file contents, `foundry-progress.json`, `CLAUDE.md`, codemap, git diff, retry errors. This is reference material the agent should use but shouldn't override task constraints.

  The invocation becomes:
  ```bash
  claude --print --output-format json \
    --system-prompt "$(cat .foundry/task-system-prompt.txt)" \
    --model "${model_hint}" \
    --max-turns 50 \
    -p "$(cat .foundry/task-context.txt)"
  ```

  Why this matters: when the system prompt says "do NOT modify files outside src/services/", that instruction has higher authority than if the same text appeared in a piped file. For harness-controlled execution, constraints must be enforced at the highest level.

- **Output parsing:** extract from Claude Code's JSON response: `result` (success/failure/error), `cost` (input/output tokens), `session_id`, `num_turns`, `duration_ms`.

#### 1.2 External Verification Pipeline

After the agent exits successfully, the wrapper runs verification commands from the project's preset:

- Execute each command sequentially in the task's `working_dir`
- Capture exit code, stdout, stderr, duration for each
- **Short-circuit on first required failure** — don't waste time running tests if lint fails
- Return structured result: `{ passed: bool, results: [{ name, command, exit_code, stdout, stderr, duration_ms }] }`
- Verification is completely external — the agent has already exited. This is the Stripe principle: the agent cannot influence or reinterpret verification results.

Verification presets are defined in the project's `foundry.json` (shared with Layer 0) so there's one source of truth for what "passing" means.

#### 1.3 Semantic Evaluation Step

Before running external verification, the wrapper performs a lightweight semantic check: did the agent's output actually address the task?

- Parse the git diff of what the agent changed
- If the diff is empty (agent made no changes), mark as `semantic_failure` — skip verification entirely
- If acceptance criteria are defined, run a fast LLM evaluation (Haiku-tier, ~500 tokens): "Given this diff and these acceptance criteria, does the diff address the criteria? Respond YES or NO with a one-line reason."
- This catches a class of failures that external verification misses: the agent changed the wrong files, implemented something unrelated, or made superficial changes that pass lint but don't address the task
- If semantic eval fails: treat as a retry-worthy failure with the eval's reason appended to retry context
- Cost: ~$0.001 per evaluation (Haiku, 500 token prompt + 50 token response). Negligible compared to a wasted full retry.

#### 1.4 Retry Engine

On verification failure, semantic failure, or agent failure:

- Check if `retry_count < max_retries`
- **Model escalation:** if `retry_escalation` is enabled and the current model is sonnet, switch to opus for the retry (the task may need more capable reasoning)
- Assemble retry context:
  - Original task description
  - "PREVIOUS ATTEMPT FAILED:" header
  - The specific verification command(s) that failed, or the semantic evaluation result
  - Their stdout/stderr (truncated to last 200 lines if very long)
  - If the agent produced a diff, include it so the retry session knows what was already tried
  - **Failed approaches from progress file:** read `foundry-progress.json` → `failed_approaches` array. Include any entries relevant to this task so the agent doesn't repeat known dead ends.
- Launch a new Claude Code session with the enriched prompt (using `--system-prompt` for constraints, piped context for error details)
- If Layer 0 is installed, the new session also reads `foundry-progress.json` and the handoff note from the failed session
- **After each failed attempt:** append to the progress file's `failed_approaches` array: `{ task, approach (from diff), error (from verification), session }`

**Retry escalation:**
- Attempt 1: original prompt (sonnet)
- Attempt 2: original + error from attempt 1 (opus if escalation enabled)
- Attempt 3 (if configured): original + errors from attempts 1 and 2 + hint: "Consider a different approach. Previously failed approaches: [list from progress file]"
- After max retries: mark as `failed_needs_human`, print full diagnostic summary

#### 1.5 State & Logging

- **Execution log:** each task execution produces a log entry in `.foundry/executions/<task-id>/`:
  ```
  .foundry/executions/task-20260316-001/
  ├── task.json           # The original task definition
  ├── attempt-1/
  │   ├── prompt.txt      # Assembled prompt sent to agent
  │   ├── stdout.json     # Agent's structured output
  │   ├── stderr.txt      # Agent's stderr
  │   ├── verification.json  # Verification results
  │   └── meta.json       # { duration_ms, tokens, exit_code, result }
  ├── attempt-2/
  │   └── ...
  └── summary.json        # Final result, total duration, total tokens, outcome
  ```
- **File-based state** — no database in Layer 1. Everything is files in `.foundry/`. This keeps the wrapper dead simple and makes state inspectable with `cat` and `jq`.
- **Git integration:**
  - Pre-execution: check for clean working directory. Warn if dirty, refuse if `--strict` flag.
  - Post-verification-pass: `git add -A && git commit -m "<type>: <summary> [foundry:<task-id>]"`
  - Post-failure: `git stash` any uncommitted changes, log the stash ref

#### 1.6 CLI Interface

```bash
# Single task execution
foundry exec --task "Add rate limiting middleware" --dir ./my-project --verify node-typescript
foundry exec --task-file task.json
foundry exec --task-file task.json --retries 3 --timeout 1200 --model opus

# Phased execution (research → plan → implement → review → verify)
foundry exec --task-file task.json --mode phased

# Check execution results
foundry log task-20260316-001
foundry log task-20260316-001 --attempt 2 --show-stderr
foundry log --last              # Show most recent execution

# Verify manually (run the verification preset without an agent)
foundry verify --dir ./my-project --preset node-typescript

# Benchmark: A/B test with vs without Foundry Layer 0
foundry benchmark --task-file task.json --dir ./my-project

# Check agent health
foundry agent check
```

**Out of scope for MS-H1:** Multi-task orchestration, plans, dependency graphs, approval workflows, daemon, web UI, TUI. This layer does one task at a time, well.

**De-risk:**
1. **Claude Code `--print --output-format json` reliability** — the critical subprocess question. Can we consistently get structured, parseable output? What happens with permission prompts? Does `--print` suppress interactivity? Build a test matrix: successful completion, context exhaustion, timeout, crash, permission denial, network error.
2. **`--system-prompt` injection behavior** — does injecting task constraints via `--system-prompt` actually produce higher instruction adherence than piping them in the prompt? Test with scope restriction violations: inject "do NOT modify files outside src/services/" via system prompt vs via piped context, measure how often the agent respects the constraint.
3. **Semantic evaluation accuracy** — does the Haiku-tier eval reliably distinguish "diff addresses the task" from "diff is unrelated"? Test with 20+ real diffs across pass/fail cases. If accuracy is <90%, the eval adds latency without value — consider making it opt-in.
4. **Model escalation cost** — does retrying failed sonnet tasks with opus actually improve pass rate enough to justify the ~3x cost? Benchmark across 10+ representative tasks. If opus retry pass rate is <50% higher than sonnet retry, the escalation isn't worth it.
5. **Stderr capture** — Claude Code may write progress indicators, warnings, or errors to stderr. Need to distinguish between Claude Code's stderr and the agent's actual error output. Test and document the output contract.
6. **Node.js vs Rust for this layer** — Node.js is faster to build, but if the wrapper is long-lived (e.g., watching a task execute for 15 minutes), memory overhead matters. Start with Node.js, benchmark, decide if Rust rewrite is needed before Layer 2.

---

### MS-H2: Plan Orchestrator ("Multi-task brains")

**Goal:** Accept a high-level objective, decompose it into ordered tasks via LLM, present for approval, and execute the full plan by feeding tasks sequentially through Layer 1's verified execution loop. Cross-task context bridging via progress files.

**Dependency:** MS-H1 (each task in a plan executes through Layer 1's verification/retry loop).

**Delivery:** Extension of the Layer 1 CLI tool. Adds `decompose`, `plan`, and multi-task execution commands.

#### 2.1 Decomposition Engine

- Takes an objective and produces a proposed task list
- Calls Anthropic API directly (`reqwest` or `fetch` → `api.anthropic.com/v1/messages`) with structured output
- Model: configurable, default `claude-sonnet-4-20250514` (Sonnet for speed/cost on planning)
- **Input context for decomposition:**
  - The objective text / PRD section
  - Project file tree (`tree -I 'node_modules|.git|dist' --noreport -L 3`)
  - `CLAUDE.md` contents
  - `foundry.json` contents
  - `foundry-progress.json` if continuing a prior effort
  - Token budget: ~10K tokens
- **Output:** JSON array of tasks, each with:
  - `id`, `description`, `relevant_files`, `acceptance_criteria`
  - `depends_on: string[]` — IDs of tasks this depends on
  - `parallelizable: bool` — can run concurrently with other independent tasks (used in Layer 3)
  - `complexity: "small" | "medium" | "large"` — estimated scope
  - `model_hint: "sonnet" | "opus"` — derived from complexity and task type. `"small"` → sonnet, `"large"` → opus, `"medium"` → sonnet (escalate on retry). Architectural/security tasks default to opus regardless of size.
  - `execution_mode: "direct" | "phased"` — `"direct"` for most tasks, `"phased"` for tasks flagged as high-risk or spanning 5+ files. Phased mode runs research → plan → implement → review → verify with subagents at each step.
- **Validation:** parse into typed structs (or Zod schema in Node.js). If parsing fails, retry API call once with clarifying instruction.
- **Decomposition can optionally be split into two phases** (inspired by the two-instance kickoff pattern): a research phase (gather documentation, analyze existing code, identify constraints) feeding a planning phase (create task list from research output). For simple objectives, single-phase decomposition is sufficient. For complex objectives involving unfamiliar codebases or external services, two-phase produces better task lists because the planner has richer context.

#### 2.2 Plan Data Model

Plans are stored as JSON files in `.foundry/plans/`:

```
.foundry/plans/plan-003-trend-analysis/
├── plan.json              # Plan metadata + task list + dependency graph
├── tasks/
│   ├── task-001.json      # Individual task definitions (Layer 1 task format)
│   ├── task-002.json
│   └── ...
├── graph.json             # Adjacency list for dependency visualization
└── status.json            # Current execution state
```

**`plan.json`:**
```json
{
  "id": "plan-003",
  "name": "Implement trend analysis pipeline",
  "objective": "Original PRD section text...",
  "status": "executing",
  "branch": "foundry/plan-003-trend-analysis",
  "decomposition_model": "claude-sonnet-4-20250514",
  "decomposition_tokens": 2450,
  "tasks": [
    {
      "id": "task-001",
      "description": "Create TrendAnalyzer service scaffold",
      "relevant_files": ["src/services/"],
      "acceptance_criteria": ["TrendAnalyzer class exists with score(), analyze(), persist() methods", "All methods are typed stubs that throw 'not implemented'", "File exports the class"],
      "depends_on": [],
      "parallelizable": true,
      "complexity": "small",
      "model_hint": "sonnet",
      "execution_mode": "direct",
      "status": "completed",
      "execution_id": "exec-20260316-001"
    }
  ],
  "created_at": "2026-03-16T20:00:00Z",
  "approved_at": "2026-03-16T20:05:00Z"
}
```

No SQLite in Layer 2. File-based state continues. This means the orchestrator can be fully understood by reading JSON files — no opaque database to debug.

#### 2.3 Approval Flow (CLI-based)

```bash
# Decompose and show proposed plan
foundry decompose --prd docs/prometheus-ms2.md --project ./

# Interactive approval
foundry plan review plan-003
#   Shows task list with dependencies
#   [a]pprove all / [e]dit task N / [r]eorder / [d]elete task / [+]add task / [x]reject

# Edit a task before approval
foundry plan edit plan-003 task-005 --depends-on task-001,task-002
foundry plan edit plan-003 task-005 --description "Updated description..."

# Add a manual task
foundry plan add plan-003 --after task-002 --description "Manual task" --files "src/foo.ts"

# Approve and start execution
foundry plan approve plan-003

# Or reject and re-decompose with feedback
foundry plan reject plan-003 --feedback "Tasks 4 and 5 should be combined, and add a task for error handling"
```

#### 2.4 Plan Execution Engine

Sequential execution following topological sort of the dependency graph:

1. Create feature branch: `git checkout -b foundry/plan-<id>-<slug>`
2. Resolve execution order via topological sort (Kahn's algorithm)
3. For each task in order:
   a. Check all dependencies are `completed`. If any is `failed`, mark this task as `blocked`.
   b. Assemble task context: task definition + `foundry-progress.json` (updated by previous tasks via Layer 0) + git diff of what changed since plan start
   c. Invoke Layer 1's execution loop (`foundry exec --task-file tasks/task-N.json`)
   d. On success: update `plan.json` status, update `foundry-progress.json` with completion summary
   e. On failure after retries: mark task as `failed_needs_human`, check if any remaining tasks are independent of it (continue those), stop tasks that depend on it
4. On plan completion: print summary, leave branch ready for review/merge

**Cross-task context bridging:**

The key mechanism: each task's Layer 0 skills update `foundry-progress.json` during execution. The Layer 2 orchestrator also updates it between tasks. So when task 4 starts, it has:
- Its own task description and acceptance criteria (from the plan)
- The progress file showing tasks 1-3 completed, with summaries, file changes, and architectural decisions
- The git diff of all changes since the plan started (compact view of what's been built)
- The plan overview showing remaining tasks (so it knows what's coming and can make forward-compatible decisions)

This is the Anthropic two-agent bridging pattern, fully automated.

#### 2.5 Extended CLI

```bash
# Decomposition
foundry decompose --prd <file>         Decompose a PRD/objective into a plan
foundry decompose --inline "..."       Decompose from text
foundry decompose --continue plan-003  Add tasks to an existing plan

# Plan management
foundry plan list                      List all plans
foundry plan show <id>                 Show plan with task graph (ASCII)
foundry plan review <id>               Interactive approval
foundry plan approve <id>              Approve and start execution
foundry plan reject <id> --feedback    Reject with feedback for re-decomposition
foundry plan edit <id> <task>          Edit a task
foundry plan add <id>                  Add a task
foundry plan remove <id> <task>        Remove a task
foundry plan cancel <id>               Cancel an executing plan
foundry plan resume <id>               Resume a paused/partially_completed plan
foundry plan status <id>               Execution status with task-by-task detail

# Orchestrated execution
foundry run plan-003                   Execute an approved plan
foundry run plan-003 --dry-run         Show execution order without running
foundry run plan-003 --from task-005   Resume from a specific task
```

**Out of scope for MS-H2:** Daemon, web UI, TUI, parallel execution, multiple simultaneous plans, webhook triggers.

**De-risk:**
1. **Decomposition quality** — test with 5+ real objectives (greenfield feature, bug fix, refactor, dependency update, documentation). Metric: % of tasks that execute successfully without manual editing of the proposed plan.
2. **Progress file as context bridge** — does it provide enough context for coherence across tasks, or do later tasks make decisions that conflict with earlier ones? Run a 5+ task plan end-to-end and evaluate the final result.
3. **Dependency graph correctness** — does the LLM correctly identify dependencies, or miss implicit ones (task B needs types defined in task A)? May need a post-decomposition validation pass.
4. **File-based state durability** — if the orchestrator crashes mid-plan, can it resume cleanly from the JSON state files? Test crash recovery by killing the process at various points.

---

### MS-H3: Rust Daemon + APIs ("Always-on infrastructure")

**Goal:** Migrate the orchestration logic from the Node.js CLI into a permanent Rust daemon with HTTP API, WebSocket streaming, resource management, and crash recovery. This is the Layer 3 that makes Foundry a systemd service you install once and forget.

**Dependency:** MS-H2 (the daemon wraps the same orchestration logic, now as a long-lived service).

**Delivery:** Rust binary (`foundry-daemon`) + systemd unit file + migration of CLI commands to API-backed thin clients.

#### 3.1 Daemon Core

- **Rust binary** with `tokio` async runtime, `axum` HTTP framework, `rusqlite` for SQLite
- **systemd integration:** `sd_notify` for readiness/watchdog, journal logging, resource limits via unit file
- **Signal handling:** SIGTERM → graceful shutdown (finish current task, persist state). SIGHUP → reload config. SIGINT → same as SIGTERM.
- **Crash recovery:** on startup, scan for tasks with status `executing` → mark as `interrupted`, optionally re-queue. PID file prevents double-start.
- **Resource monitoring:** track daemon RSS, child process CPU/RAM, disk usage. Pause queue if system resources are constrained (configurable thresholds).

#### 3.2 State Migration: Files → SQLite

Layer 2's file-based state served its purpose — now migrate to SQLite for query performance, atomic updates, and concurrent access from API handlers.

```sql
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    plan_id TEXT,
    status TEXT NOT NULL,
    description TEXT NOT NULL,
    working_dir TEXT NOT NULL,
    relevant_files TEXT,           -- JSON array
    acceptance_criteria TEXT,      -- JSON array
    verification_preset TEXT,
    retry_policy TEXT,             -- JSON
    retry_count INTEGER DEFAULT 0,
    agent_name TEXT DEFAULT 'claude-code',
    sequence_order INTEGER,
    depends_on TEXT,               -- JSON array of task IDs
    parallelizable BOOLEAN DEFAULT FALSE,
    complexity TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    completed_at TEXT,
    git_commit TEXT,
    error_summary TEXT
);

CREATE TABLE plans (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    objective TEXT NOT NULL,
    status TEXT NOT NULL,
    branch_name TEXT,
    decomposition_model TEXT,
    total_tasks INTEGER,
    completed_tasks INTEGER DEFAULT 0,
    failed_tasks INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    approved_at TEXT,
    completed_at TEXT,
    updated_at TEXT NOT NULL
);

CREATE TABLE executions (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL REFERENCES tasks(id),
    attempt INTEGER NOT NULL,
    agent_name TEXT NOT NULL,
    status TEXT NOT NULL,
    prompt_hash TEXT,
    stdout TEXT,
    stderr TEXT,
    exit_code INTEGER,
    duration_ms INTEGER,
    input_tokens INTEGER,
    output_tokens INTEGER,
    verification_results TEXT,     -- JSON array
    files_changed TEXT,            -- JSON array
    created_at TEXT NOT NULL
);

CREATE TABLE task_dependencies (
    task_id TEXT NOT NULL REFERENCES tasks(id),
    depends_on_task_id TEXT NOT NULL REFERENCES tasks(id),
    PRIMARY KEY (task_id, depends_on_task_id)
);
```

- **WAL mode** for concurrent read/write
- **Migrations** embedded in binary via `include_str!`
- **DB location:** `~/.local/share/foundry/foundry.db`

#### 3.3 HTTP API

```
POST   /api/tasks                  Submit a new task
GET    /api/tasks                  List tasks (filter by status, plan_id)
GET    /api/tasks/:id              Get task details
POST   /api/tasks/:id/retry        Retry a failed task
POST   /api/tasks/:id/cancel       Cancel a queued/executing task

POST   /api/plans                  Create plan from objective (triggers decomposition)
GET    /api/plans                  List plans
GET    /api/plans/:id              Get plan with tasks and dependency graph
POST   /api/plans/:id/approve      Approve plan
POST   /api/plans/:id/cancel       Cancel plan
POST   /api/plans/:id/resume       Resume paused plan
POST   /api/plans/:id/redecompose  Re-decompose with feedback
PATCH  /api/plans/:id/tasks/:id    Edit a task in a pending plan
POST   /api/plans/:id/tasks        Add a task to a plan
DELETE /api/plans/:id/tasks/:id    Remove a task from a plan
GET    /api/plans/:id/graph        Dependency graph (adjacency list)

GET    /api/executions/:task_id    Execution history for a task
WS     /api/stream/:task_id        WebSocket: real-time log streaming

GET    /api/health                 Daemon health + metrics
GET    /api/agents                 Available agent adapters
GET    /api/config                 Current configuration
PUT    /api/config/:key            Update config value
```

- Bind to `127.0.0.1:7400` (localhost only)
- JSON request/response with error envelopes
- CORS configurable for web UI development

#### 3.4 AgentAdapter Trait

```rust
#[async_trait]
pub trait AgentAdapter: Send + Sync {
    async fn execute(&self, request: &AgentRequest) -> Result<AgentResponse>;
    async fn health_check(&self) -> Result<AgentHealth>;
    fn capabilities(&self) -> AgentCapabilities;
    fn name(&self) -> &str;
}
```

- **`ClaudeCodeAdapter`:** subprocess invocation of `claude` CLI
- Trait designed so adding Codex, Aider, or direct API adapters later is one implementation, not a restructure
- Each adapter declares capabilities (supports structured output? manages own git? read-only mode? token reporting?)

#### 3.5 CLI becomes thin client

The `foundry` CLI commands now talk to the daemon via HTTP:
- `foundry exec ...` → `POST /api/tasks`
- `foundry plan ...` → `/api/plans` endpoints
- `foundry status` → `GET /api/health` + `GET /api/tasks?status=executing`
- `foundry logs -f` → WebSocket connection to `/api/stream/:task_id`
- If daemon isn't running, CLI prints helpful message and offers to start it

#### 3.6 Parallel Execution (unlocked by daemon)

- Configurable `max_concurrent_tasks` (default: 1, increase when ready)
- Independent tasks in a plan run in parallel using `tokio::spawn`
- Each parallel task gets its own **git worktree**: `git worktree add .foundry/worktrees/<task-id> -b foundry/task-<id>`
- On task completion, merge worktree back to plan branch. Handle merge conflicts by marking task as `conflict_needs_human`.
- Resource-aware: monitor system RAM, pause new task spawns if below threshold

#### 3.7 Daemon Safety

```ini
[Unit]
Description=Foundry Development Workspace Daemon
After=network.target

[Service]
Type=notify
ExecStart=/usr/local/bin/foundry-daemon
Restart=on-failure
RestartSec=5
WatchdogSec=30
MemoryMax=512M
CPUQuota=80%
TasksMax=64

[Install]
WantedBy=default.target
```

- **Memory:** Rust ownership model prevents leaks. Bounded ring buffers for log capture. SQLite WAL handles write performance.
- **Graceful shutdown:** finish current task (with timeout), persist state, close DB.
- **Watchdog:** periodic `sd_notify(WATCHDOG=1)` heartbeats. Hung daemon gets restarted automatically.
- **Log rotation:** `tracing-appender` with rolling files, 10MB per file, 5 rotations.

#### 3.8 Rust Dependencies

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
reqwest = { version = "0.12", features = ["json"] }
git2 = "0.19"
notify-rust = "4"
```

**Out of scope for MS-H3:** Web UI, TUI, task tracker, goals, summaries. Those are Foundry workspace features (MS3-5 of the parent PRD).

**De-risk:**
1. **File-to-SQLite migration** — can Layer 2's file-based state be migrated cleanly? Need a one-time migration tool that reads `.foundry/plans/` and populates SQLite.
2. **Git worktree merge conflicts** — how often do parallel tasks produce conflicts? Test with real codebases before enabling parallel by default.
3. **Daemon memory profile** — does the Rust daemon actually stay under 50MB RSS at idle? Benchmark early with realistic workloads.

---

## Architecture Summary

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
│  │ (Anthropic   │ │ Graph +     │ │ (sequential, feeds tasks  │ │
│  │  API direct) │ │ Topo Sort   │ │  to Layer 1 loop)         │ │
│  └──────────────┘ └─────────────┘ └─────────────┬─────────────┘ │
│                                                  │               │
├──────────────────────────────────────────────────┼───────────────┤
│  Layer 1: Session Wrapper (MS-H1)                │               │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────┴─────────┐   │
│  │ Context      │ │ External     │ │ Retry Engine          │   │
│  │ Assembly     │ │ Verification │ │ (enriched context     │   │
│  │              │ │ Pipeline     │ │  on each attempt)     │   │
│  └──────┬───────┘ └──────┬───────┘ └───────────┬───────────┘   │
│         └────────────────┴─────────────────────┘               │
│                              │ invokes                          │
├──────────────────────────────┼───────────────────────────────────┤
│  Layer 0: Claude Code Enhancements (MS-H0)       │               │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ HOOKS (always active, external enforcement)             │    │
│  │ ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌───────────┐  │    │
│  │ │UserPrompt│ │PostToolUse│ │PreToolUse│ │   Stop    │  │    │
│  │ │ Submit   │ │ typecheck │ │ scope    │ │  audit    │  │    │
│  │ │ (init,   │ │ format    │ │ enforce  │ │  cleanup  │  │    │
│  │ │  inject) │ │ quality   │ │ block md │ │  handoff  │  │    │
│  │ └──────────┘ │ gates     │ │ tmux     │ └───────────┘  │    │
│  │              └───────────┘ └──────────┘                 │    │
│  │ ┌─────────┐ ┌────────────┐                              │    │
│  │ │PreCompct│ │Notification│                              │    │
│  │ │auto-save│ │notify-send │                              │    │
│  │ └─────────┘ └────────────┘                              │    │
│  ├─────────────────────────────────────────────────────────┤    │
│  │ RULES (always in context, ~2K tokens)                   │    │
│  │ workflow.md │ scope.md │ quality.md │ context.md │git.md│    │
│  ├─────────────────────────────────────────────────────────┤    │
│  │ SKILLS (loaded on demand via search script)             │    │
│  │ /plan │ /verify │ /progress │ /checkpoint │ /codemap   │    │
│  │ /context │ /handoff │ /parallel │ /review │ /clean     │    │
│  ├─────────────────────────────────────────────────────────┤    │
│  │ SUBAGENTS (delegated, scoped tool access)               │    │
│  │ planner (read-only) │ verifier (bash-only)              │    │
│  │ reviewer (read-only) │ context-builder (read-only)      │    │
│  │ refactorer (write, scoped to cleanup)                   │    │
│  ├─────────────────────────────────────────────────────────┤    │
│  │ STATE (file-system-as-state)                            │    │
│  │ foundry-progress.json │ codemap.md │ handoff-note.md    │    │
│  │ session-log.jsonl │ found-issues.md │ plans/*.md        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │ runs inside                       │
├──────────────────────────────┼───────────────────────────────────┤
│  Claude Code Session         │                                   │
│  (with Foundry plugin + optionally Superpowers)                  │
└─────────────────────────────────────────────────────────────────┘
```

### What each layer can do independently

| You have... | You can... |
|---|---|
| Layer 0 only | Structured planning, continuous typecheck on every edit, auto-formatting, progress tracking across sessions (including failed approaches), codemap navigation, quality gates, scoped subagents for review and planning, cross-session handoff, pre-compaction checkpointing, strategic compaction at logical boundaries, continuous learning (session knowledge extraction), MCP-to-CLI token optimization, desktop notifications, A/B benchmarking of skill effectiveness |
| Layer 0 + 1 | All of above + fire-and-forget single tasks with system-prompt-injected constraints, semantic evaluation before verification, external verification pipeline, automated retries with model escalation (sonnet→opus), failed approach tracking, phased execution mode for complex tasks, structured execution logs |
| Layer 0 + 1 + 2 | All of above + multi-task plan execution from PRD decomposition with model hints per task, dependency ordering, two-phase decomposition for complex objectives, approval flow, cross-task context bridging |
| Layer 0 + 1 + 2 + 3 | All of above + always-on daemon with API, parallel execution via git worktrees, SQLite state, WebSocket log streaming, crash recovery, resource monitoring |

### Implementation Order & Timeline Estimate

| Milestone | Effort | Stack | Deliverable |
|---|---|---|---|
| MS-H0 | 2-3 weeks | Markdown, shell scripts, JSON, TOML | Claude Code plugin: skills, rules, hooks, subagents, codemap, learning, commands |
| MS-H1 | 2-3 weeks | Node.js/TypeScript | CLI wrapper (`foundry exec`, `foundry verify`, `foundry benchmark`) with system-prompt injection, semantic eval, model escalation |
| MS-H2 | 2-3 weeks | Node.js/TypeScript (extends H1) | CLI orchestrator (`foundry decompose`, `foundry plan`, `foundry run`) with model hints and two-phase decomposition |
| MS-H3 | 3-4 weeks | Rust | Daemon binary + systemd unit + API |

### MS-H0 Internal Phasing

MS-H0 is the largest milestone by component count. To avoid shipping everything at once, phase it internally:

| Phase | Scope | Effort |
|---|---|---|
| H0.1 | Plugin scaffold, `foundry init`, `foundry.json`, basic rules, session-start hook, `/foundry:status` | 3-4 days |
| H0.2 | Core skills: `/foundry:plan`, `/foundry:verify`, `/foundry:checkpoint`, `/foundry:progress` | 3-4 days |
| H0.3 | PostToolUse hooks: continuous typecheck, auto-format, quality gates, change tracking | 2-3 days |
| H0.4 | Cross-session: `/foundry:handoff`, `/foundry:codemap`, `/foundry:context`, PreCompact hook | 2-3 days |
| H0.5 | Subagents: planner, verifier, reviewer, delegation rules. Scope enforcement hooks. | 2-3 days |
| H0.6 | Continuous learning: `/foundry:learn`, Stop hook evaluator, `.foundry/learned/` system | 2-3 days |
| H0.7 | Strategic compaction: `/foundry:compact`, tool-call counter, compaction strategy config | 1-2 days |
| H0.8 | Polish: Superpowers compat, `/foundry:benchmark`, MCP cli_alternatives, Codex/OpenCode install, marketplace listing | 2-3 days |

Ship H0.1-H0.2 first — that alone gives you structured planning, verification, and progress tracking. H0.3 adds the continuous typecheck that catches errors in real-time. Everything after is incremental improvement that compounds over time.
