---
name: foundry-verify
description: >
  Run project verification pipeline and report results. Executes typecheck, lint, test as configured
  in foundry.json. Trigger: "verify", "check", "run checks", "is it passing?".
version: 0.1.0
---

# /foundry-verify — Run Verification Pipeline

## What it does

Runs all enabled verification steps from `foundry.json` and reports structured results.

## Steps

1. **Read `foundry.json`** from project root. If not found, fall back to sensible defaults:
   - If `tsconfig.json` exists: run `npx tsc --noEmit --pretty`
   - If `package.json` has test script: run `npm test`

2. **Run each enabled verification step** in order:
   - **Typecheck** (`verification.typecheck`) — run command, capture exit code + output
   - **Lint** (`verification.lint`) — run command, capture exit code + output
   - **Test** (`verification.test`) — run command, capture exit code + output

3. **Report results** in this format:
   ```
   ## Verification Results
   - Typecheck: PASS ✓ (2.1s)
   - Lint: SKIP (disabled)
   - Test: FAIL ✗ (4.3s)
     > 2 failed: test/auth.test.ts:45, test/auth.test.ts:72
   ```

4. **Short-circuit** on first failure if user passes `--bail`.

## Arguments

- No args: run all enabled checks
- `typecheck` / `lint` / `test`: run specific check only
- `--bail`: stop on first failure

## Important

- Pipe command output through `head -30` to avoid flooding context
- Capture both stdout and stderr
- Report wall-clock time for each step
- Return structured pass/fail — don't interpret results subjectively
