# Delegation Rules

These rules apply when `features.delegation` is enabled in foundry.json.

1. **Delegate planning.** Use the `foundry-planner` agent for plan creation — it reads the codebase without modifying it.
2. **Delegate verification.** Use the `foundry-verifier` agent for running checks — keeps verification isolated.
3. **Delegate review.** Use the `foundry-reviewer` agent before checkpoints — catches issues you might miss.
4. **Delegate context.** Use the `foundry-context-builder` agent for unfamiliar areas — saves main context window.
5. **Delegate cleanup.** Use the `foundry-refactorer` agent after feature completion — focused cleanup pass.
6. **Never delegate implementation.** Core feature work stays in the main session for continuity.
