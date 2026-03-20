---
name: foundry-codemap
description: >
  Generate .foundry/codemap.md — project structure overview with exports, entry points, and recent
  git activity. Trigger: "codemap", "generate codemap", "map the codebase", "project structure".
version: 0.1.0
---

# /foundry-codemap — Generate Project Codemap

## What it does

Generates `.foundry/codemap.md` — a compact project structure overview for quick orientation.

## Steps

1. **Run `generate-codemap.sh`** from the Foundry plugin scripts directory:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/generate-codemap.sh" "$CWD"
   ```
   Or manually generate with equivalent logic below.

2. **If script unavailable, generate manually:**

   a. **File tree** (depth 3, exclude node_modules/.git/.foundry):
   ```bash
   tree -L 3 -I 'node_modules|.git|.foundry|dist|build|coverage' --dirsfirst
   ```

   b. **Exported symbols** from key files (src/**/*.ts entry points):
   ```bash
   grep -rn '^export' src/ --include='*.ts' | head -50
   ```

   c. **Recent git activity** (last 10 commits with files):
   ```bash
   git log --oneline --name-only -10
   ```

   d. **Package dependencies** (from package.json):
   ```bash
   cat package.json | python3 -c "import json,sys; d=json.load(sys.stdin); print('\n'.join(d.get('dependencies',{}).keys()))"
   ```

3. **Write output** to `.foundry/codemap.md` with sections:
   ```markdown
   # Codemap — <project-name>
   Generated: <ISO date>

   ## File Structure
   <tree output>

   ## Key Exports
   <export grep results>

   ## Recent Activity
   <git log>

   ## Dependencies
   <dependency list>
   ```

## Important

- Regenerate after significant structural changes (new files/dirs, refactors)
- Keep output under 2000 lines — use `head` to cap sections
- The codemap is a starting point for exploration, not exhaustive documentation
