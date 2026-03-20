# Git Rules

1. **Conventional commits.** Format: `type(scope): description`. Types: feat, fix, refactor, test, docs, chore.
2. **Incremental commits.** Commit after each logical unit of work, not giant batches.
3. **No force push.** Never `git push --force` without explicit user approval.
4. **Feature branches.** Never commit directly to `main` or `staging`. Use `feat/` or `fix/` branches.
5. **Clean diffs.** Don't include unrelated changes, whitespace-only edits, or formatting in feature commits.
