# Plan: Bridge Layer 0 Into the Harness

## Summary

The harness (`foundry exec`) invokes Claude Code as a dumb black box — generic system prompt, no project rules, no CLAUDE.md, no codemap. Meanwhile, Layer 0 has rules, skills definitions, and project conventions sitting unused during headless execution. This plan injects L0 context into the harness's `assembleContext()` so headless sessions benefit from the same discipline as interactive ones.

## Affected Files

| File | Change |
|---|---|
| `packages/cli/src/exec/context.ts` | Add L0 context loading (rules, CLAUDE.md, codemap) |
| `packages/cli/src/exec/context.test.ts` | Tests for new context injection |
| `packages/cli/src/shared/schema.ts` | Add optional `context` config section to FoundryConfigSchema |
| `packages/cli/src/shared/config.ts` | Add `tryReadDir`, `tryReadFile` helpers |

## Dependencies

None new. Uses existing `node:fs/promises` only.

## Data Flow

```
executeTask()
  └─ assembleContext()
       ├─ [existing] base system prompt (project, language, constraints)
       ├─ [NEW] CLAUDE.md → append to system prompt as project conventions
       ├─ [NEW] .foundry/rules/*.md → concat, inject into system prompt constraints
       ├─ [NEW] .foundry/codemap.md → append system prompt as navigation context
       ├─ [existing] progress context (completed, failed approaches, decisions)
       ├─ [existing] retry context
       └─ [existing] context files
```

**Token budget consideration:** Rules are ~2K tokens total, CLAUDE.md capped at 3K, codemap capped at 3K. Worst case adds ~8K tokens to system prompt. Acceptable — `--max-turns 20` sessions have 200K+ context window.

## Schema Changes

Add optional `context` field to `FoundryConfigSchema`:

```typescript
context: z.object({
  inject_rules: z.boolean().default(true),
  inject_claude_md: z.boolean().default(true),
  inject_codemap: z.boolean().default(true),
  rules_dir: z.string().default(".foundry/rules"),
  codemap_file: z.string().default(".foundry/codemap.md"),
  claude_md_max_chars: z.number().default(3000),
  codemap_max_chars: z.number().default(3000),
  rules_max_chars: z.number().default(2000),
}).default({})
```

All defaults `true` — the bridge is on by default, opt-out via config.

## Implementation Steps

### Step 1: Add `tryReadFile` helper to config.ts

`config.ts` already has `tryLoadConfig` / `tryLoadProgress`. Add a generic `tryReadFile(path): Promise<string | null>` (decompose.ts already has a local one — hoist it to shared).

**Test:** unit test: returns content for existing file, null for missing.

### Step 2: Add context config to schema

Add `ContextConfigSchema` to `schema.ts`, nest inside `FoundryConfigSchema` as `context` field with defaults.

**Test:** existing schema tests still pass + new test: context defaults parse correctly, overrides work.

### Step 3: Load and inject CLAUDE.md in assembleContext

Read `CLAUDE.md` from project root (same as decompose.ts does). Inject as `## Project Conventions (CLAUDE.md)` section in system prompt. Cap at `config.context.claude_md_max_chars`. Skip if `inject_claude_md: false` or file missing.

**Test:**
- With CLAUDE.md present → system prompt contains conventions section
- Without CLAUDE.md → no conventions section
- With `inject_claude_md: false` → skipped even if file exists
- Content truncated at limit

### Step 4: Load and inject .foundry/rules/*.md

Read all `.md` files from `config.context.rules_dir`. Concat with headers. Inject as `## Rules` section in system prompt after constraints. Cap total at `config.context.rules_max_chars`. Skip if `inject_rules: false` or dir missing/empty.

**Test:**
- With rules dir containing files → system prompt contains rules section
- Empty dir → no rules section
- Truncation at limit
- Disabled via config → skipped

### Step 5: Load and inject codemap

Read `config.context.codemap_file` if it exists. Inject as `## Codebase Map` in append system prompt (lower authority than rules — it's reference material, not constraints). Cap at `config.context.codemap_max_chars`. Skip if `inject_codemap: false` or file missing.

**Test:**
- With codemap → append prompt contains codebase map section
- Without → no section
- Disabled via config → skipped

### Step 6: Update ContextAssemblyInput to carry config.context

`assembleContext` already receives `config: FoundryConfig`. The new `context` field is on `FoundryConfig`, so no interface change needed — just use `input.config.context` inside the function.

### Step 7: Verify end-to-end with typecheck + existing tests

`pnpm typecheck && pnpm test`

Existing tests use a `baseConfig` that doesn't include `context` — Zod defaults will fill it in. No existing tests should break.

## Testing Strategy

All unit tests via vitest. No integration tests (would require real `claude` binary).

Test fixtures:
- Temp dir with `.foundry/rules/` containing test rule files
- Temp dir with `CLAUDE.md`
- Temp dir with `.foundry/codemap.md`
- Temp dir with nothing (verify graceful skip)

## Risks

1. **Token bloat** — injecting 8K extra tokens could push small-context models over budget. Mitigated by per-section char caps and config opt-out.
2. **Rule content quality** — current L0 rules reference interactive-only concepts (`/foundry:verify`, `/foundry:checkpoint`). Headless agent can't run skills. May need to split rules into "universal" vs "interactive-only" later. For now, inject as-is — the agent will ignore inapplicable instructions.
3. **Path resolution** — rules dir path is relative to project root. Must resolve via `join(input.dir, config.context.rules_dir)`. Already the pattern used for other file reads.

## Unresolved Questions

- Filter out interactive-only rule content (references to `/foundry:` skills) before injection, or leave as-is and let agent ignore?
- Should CLAUDE.md go in system prompt (high authority) or append (reference material)? Plan puts it in system prompt since it contains project conventions/constraints.
- Cap individual rule files or just total rules payload?
