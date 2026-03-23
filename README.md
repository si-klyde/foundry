# Foundry

Agent orchestration engine for Claude Code. Makes AI coding sessions more disciplined, verified, and continuous across sessions.

## The Problem

1. **Context window cliff.** Complex features hit context limits around task 7-8. Everything learned is lost.
2. **No verification loop.** Claude Code declares success based on self-assessment. No external typecheck/test/lint enforcement.
3. **No structured retry.** When tasks fail, humans manually reconstruct context.

## Architecture

Four layers, each delivering standalone value. Built bottom-up.

```
Layer 3: Rust Daemon         ← subprocess management, queue, HTTP API, parallel via worktrees
Layer 2: CLI Orchestrator    ← multi-task plans, dependency ordering, sequential execution
Layer 1: Session Wrapper     ← external verification, retry with model escalation, state tracking
Layer 0: Claude Code Plugin  ← hooks, skills, agents, rules — inside Claude Code itself
```

**Layer 0** is shipped and dogfooded. Layers 1-3 are planned.

## Install

Requires [Claude Code](https://claude.ai/claude-code).

```bash
# In Claude Code:
/plugin marketplace add si-klyde/foundry
/plugin install foundry@foundry
```

For local development:
```bash
claude --plugin-dir /path/to/foundry/packages/layer0
```

Migrating from legacy `install.sh`? Run `bash packages/layer0/migrate.sh` first.

## What Layer 0 Gives You

### Hooks — automatic behaviors

| Hook | Trigger | What it does |
|------|---------|-------------|
| SessionStart | Session open/resume | Injects rules, progress state, handoff notes from previous session |
| PostToolUse | After Write/Edit | Typecheck on `.ts` edits, quality gates (console.log/debugger), session logging |
| PreToolUse | Before Write/Edit | Scope enforcement against active plan, warns on out-of-scope edits |
| Stop | Session end | Session audit, auto-handoff note, doc gardening sweep |

### Skills — invoke via `/skill-name`

| Skill | Purpose |
|-------|---------|
| `/foundry-init` | Initialize Foundry in a project (config + optional cascading docs) |
| `/foundry-plan` | Structured planning workflow |
| `/foundry-verify` | Run verification pipeline (typecheck/lint/test) |
| `/foundry-progress` | Track tasks, decisions, blockers across sessions |
| `/foundry-checkpoint` | Atomic: verify + review + commit + progress update |
| `/foundry-handoff` | End-of-session handoff with context preservation |
| `/foundry-status` | Project overview (plan progress, changed files, decisions) |
| `/foundry-codemap` | Generate project structure map |
| `/foundry-context` | Smart context loading for unfamiliar code areas |
| `/foundry-learn` | Extract reusable patterns to `.foundry/learned/` |
| `/foundry-compact` | Strategic compaction at phase boundaries |
| `/foundry-parallel` | Git worktree for parallel work streams |
| `/foundry-benchmark` | Session effectiveness metrics |
| `/foundry-review` | Code review via subagent |
| `/foundry-clean` | Cleanup pass via refactorer subagent |

### Agents — delegated specialists

| Agent | Role |
|-------|------|
| `foundry-planner` | Read-only planning and decomposition |
| `foundry-verifier` | Run verification checks only |
| `foundry-reviewer` | Code review against criteria |
| `foundry-context-builder` | Build context summaries |
| `foundry-refactorer` | Cleanup with write access |

### Rules — injected at session start (~1.1K tokens)

`workflow.md` · `scope.md` · `quality.md` · `context.md` · `git.md` · `delegation.md` · `integration.md` (conditional)

## Core Workflow

```
Start session → rules + progress injected automatically
  → /foundry-plan (design before coding)
  → implement (TDD, continuous typecheck)
  → /foundry-checkpoint (verify + commit + update, repeat)
  → /foundry-handoff (end session, preserve context)
```

## Design Principles

1. **The system runs the model, not the reverse.** The harness controls what task, what context, what verification, when to stop.
2. **File-system-as-state.** Progress persists to files, not in any agent's context window.
3. **External verification is non-negotiable.** The agent's opinion about whether code works is irrelevant.
4. **No API key dependency.** Everything goes through `claude --print`. No `ANTHROPIC_API_KEY` needed.
5. **Context engineering is the primary cost and quality lever.** What you put in the prompt matters more than which model you use.

## Project Structure

```
foundry/
├── .claude-plugin/          ← marketplace manifest
├── packages/layer0/         ← Claude Code plugin (hooks, skills, agents, rules)
├── docs/
│   ├── foundry-harness-prd-v3.md
│   ├── progress.md
│   └── decisions.md
└── CLAUDE.md                ← project context router
```

## Roadmap

| Milestone | Status |
|-----------|--------|
| Layer 0 — Claude Code plugin | Done, dogfooded |
| Cascading context system | Done |
| Superpowers integration | Done |
| Plugin packaging | Done |
| Layer 1 — Session wrapper CLI | Planned |
| Layer 2 — Plan orchestrator | Planned |
| Layer 3 — Rust daemon | Planned |

## License

Personal project by [Growgami](https://growgami.com).
