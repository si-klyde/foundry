## Foundry × Superpowers

Superpowers handles in-session workflow. Foundry handles infrastructure. Use both.

**Superpowers owns:** planning (writing-plans), execution (subagent-driven-development, executing-plans), debugging (systematic-debugging), TDD (test-driven-development), verification gate (verification-before-completion), code review (requesting-code-review), branch finishing (finishing-a-development-branch), parallel dispatch (dispatching-parallel-agents), brainstorming.

**Foundry owns:** reactive hooks (typecheck, quality gates, scope guard — automatic), progress tracking (/foundry-progress), context bridging (/foundry-context, /foundry-codemap, /foundry-compact), session handoff (/foundry-handoff), doc scaffolding + project init (/foundry-init), project config (foundry.json).

**Coordination:**
- After superpowers:writing-plans completes → run /foundry-progress to register the plan
- After superpowers:finishing-a-development-branch completes → run /foundry-handoff
- Foundry hooks fire automatically alongside superpowers — no action needed
- Use /foundry-checkpoint for atomic save points between superpowers execution tasks
