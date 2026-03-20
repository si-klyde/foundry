#!/usr/bin/env bash
# Foundry installer — sets up Claude Code globally with Foundry harness
# Installs: skills, agents, hooks, context system awareness in global CLAUDE.md
# Usage: install.sh [--uninstall]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_DIR}/skills"
AGENTS_DIR="${CLAUDE_DIR}/agents"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"
CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"

SKILLS=(
  foundry-init foundry-plan foundry-verify foundry-progress
  foundry-checkpoint foundry-handoff foundry-status foundry-codemap
  foundry-context foundry-learn foundry-compact foundry-parallel
  foundry-benchmark foundry-review foundry-clean
)

AGENTS=(
  planner verifier reviewer context-builder refactorer
)

HOOKS_DIR="${SCRIPT_DIR}/hooks"

# --- Context System block for global CLAUDE.md ---
CONTEXT_BLOCK_START="## Context System"
CONTEXT_BLOCK='## Context System
Projects use cascading AGENTS.md for context. CLAUDE.md is a thin router.
- `CLAUDE.md` — pointers to AGENTS.md files + verify commands + conventions only
- `AGENTS.md` per directory — gotchas, patterns, pointers to decisions.md
- `decisions.md` — ADRs (architecture decision records)
- No code snippets, no architecture explanations in AGENTS.md — terse, high-signal only
- When entering an unfamiliar directory, check for AGENTS.md before diving into code
- Doc gardening keeps AGENTS.md current automatically — do not manually update AGENTS.md unless asked

### Bootstrapping context in new/existing projects
When working in a project without cascading context (no AGENTS.md, monolith CLAUDE.md, or no CLAUDE.md at all):
- First session: work normally, learn the codebase
- Before session ends: offer to scaffold the context system:
  1. `CLAUDE.md` → thin router (or refactor existing monolith into one)
  2. `AGENTS.md` in key directories — extract gotchas/patterns learned during session
  3. `docs/decisions.md` — capture any architecture decisions discovered or made
- Do NOT auto-create without asking — some repos have their own CLAUDE.md conventions
- If CLAUDE.md exists but is a monolith: suggest refactoring, don'"'"'t overwrite
- If the project has AGENTS.md files already (OpenAI Codex convention): respect them, integrate'

# --- Uninstall ---
if [ "${1:-}" = "--uninstall" ]; then
  echo "Uninstalling Foundry..."

  # Remove skills
  for skill in "${SKILLS[@]}"; do
    rm -rf "${SKILLS_DIR}/${skill}" 2>/dev/null || true
  done
  echo "  Removed ${#SKILLS[@]} skills"

  # Remove agents
  for agent in "${AGENTS[@]}"; do
    rm -f "${AGENTS_DIR}/foundry-${agent}.md" 2>/dev/null || true
  done
  echo "  Removed ${#AGENTS[@]} agents"

  # Remove hooks from settings.json
  if [ -f "$SETTINGS_FILE" ] && command -v jq &>/dev/null; then
    TMP=$(mktemp --tmpdir="$(dirname "$SETTINGS_FILE")")
    jq '
      .hooks |= (if . then
        to_entries | map(
          .value |= map(
            .hooks |= map(select((.command // "") | test("run-hook\\.cmd") | not))
          ) | .value |= map(select(.hooks | length > 0))
        ) | map(select(.value | length > 0)) | from_entries
      else . end)
    ' "$SETTINGS_FILE" > "$TMP"
    mv "$TMP" "$SETTINGS_FILE"
    echo "  Removed hooks from settings.json"
  fi

  # Remove from enabledPlugins if present
  if [ -f "$SETTINGS_FILE" ] && command -v jq &>/dev/null; then
    TMP=$(mktemp --tmpdir="$(dirname "$SETTINGS_FILE")")
    jq 'del(.enabledPlugins["foundry@foundry-local"])' "$SETTINGS_FILE" > "$TMP"
    mv "$TMP" "$SETTINGS_FILE"
  fi

  # Remove Context System block from global CLAUDE.md
  if [ -f "$CLAUDE_MD" ] && grep -q "$CONTEXT_BLOCK_START" "$CLAUDE_MD"; then
    TMP=$(mktemp --tmpdir="$(dirname "$CLAUDE_MD")")
    awk -v start="$CONTEXT_BLOCK_START" '
      BEGIN { skip=0 }
      $0 ~ start { skip=1; next }
      skip && /^## / && $0 !~ start { skip=0 }
      !skip { print }
    ' "$CLAUDE_MD" > "$TMP"
    # Remove trailing blank lines
    sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$TMP"
    mv "$TMP" "$CLAUDE_MD"
    echo "  Removed Context System from global CLAUDE.md"
  fi

  rm -rf "${CLAUDE_DIR}/plugins/cache/foundry-local" 2>/dev/null || true

  echo "Foundry uninstalled. Restart Claude Code."
  exit 0
fi

# --- Install ---
echo "Installing Foundry..."

# 1. Copy skills
mkdir -p "$SKILLS_DIR"
for skill in "${SKILLS[@]}"; do
  SRC="${SCRIPT_DIR}/skills/${skill}"
  DST="${SKILLS_DIR}/${skill}"
  if [ -d "$SRC" ]; then
    rm -rf "$DST"
    cp -r "$SRC" "$DST"
  fi
done
echo "  Copied ${#SKILLS[@]} skills to ${SKILLS_DIR}"

# 2. Copy agents
mkdir -p "$AGENTS_DIR"
for agent in "${AGENTS[@]}"; do
  SRC="${SCRIPT_DIR}/agents/${agent}.md"
  DST="${AGENTS_DIR}/foundry-${agent}.md"
  if [ -f "$SRC" ]; then
    cp "$SRC" "$DST"
  fi
done
echo "  Copied ${#AGENTS[@]} agents to ${AGENTS_DIR}"

# 3. Make scripts executable
chmod +x "${HOOKS_DIR}/"* 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/scripts/"*.sh 2>/dev/null || true

# 4. Add hooks to settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

if command -v jq &>/dev/null; then
  TMP=$(mktemp --tmpdir="$(dirname "$SETTINGS_FILE")")
  jq \
    --arg session_cmd "\"${HOOKS_DIR}/run-hook.cmd\" session-start" \
    --arg post_cmd "\"${HOOKS_DIR}/run-hook.cmd\" post-tool-use" \
    --arg pre_cmd "\"${HOOKS_DIR}/run-hook.cmd\" pre-tool-use" \
    --arg stop_cmd "\"${HOOKS_DIR}/run-hook.cmd\" stop" \
  '
    .hooks //= {} |
    .hooks.SessionStart //= [] |
    .hooks.SessionStart |= (
      [.[] | select((.hooks[0].command // "") | test("run-hook\\.cmd") | not)] +
      [{"matcher": "*", "hooks": [{"type": "command", "command": $session_cmd, "timeout": 5}]}]
    ) |
    .hooks.PostToolUse //= [] |
    .hooks.PostToolUse |= (
      [.[] | select((.hooks[0].command // "") | test("run-hook\\.cmd") | not)] +
      [{"matcher": "Write|Edit", "hooks": [{"type": "command", "command": $post_cmd, "timeout": 10}]}]
    ) |
    .hooks.PreToolUse //= [] |
    .hooks.PreToolUse |= (
      [.[] | select((.hooks[0].command // "") | test("run-hook\\.cmd") | not)] +
      [{"matcher": "Write|Edit", "hooks": [{"type": "command", "command": $pre_cmd, "timeout": 5}]}]
    ) |
    .hooks.Stop //= [] |
    .hooks.Stop |= (
      [.[] | select((.hooks[0].command // "") | test("run-hook\\.cmd") | not)] +
      [{"matcher": "*", "hooks": [{"type": "command", "command": $stop_cmd, "timeout": 10}]}]
    )
  ' "$SETTINGS_FILE" > "$TMP"
  mv "$TMP" "$SETTINGS_FILE"
  echo "  Added 4 hooks to settings.json"
else
  echo "  ERROR: jq required for hook installation"
  exit 1
fi

# 5. Inject Context System into global CLAUDE.md
if [ ! -f "$CLAUDE_MD" ]; then
  echo "$CONTEXT_BLOCK" > "$CLAUDE_MD"
  echo "  Created global CLAUDE.md with Context System"
elif grep -q "$CONTEXT_BLOCK_START" "$CLAUDE_MD"; then
  # Replace existing block
  TMP=$(mktemp --tmpdir="$(dirname "$CLAUDE_MD")")
  awk -v start="$CONTEXT_BLOCK_START" -v block="$CONTEXT_BLOCK" '
    BEGIN { skip=0; printed=0 }
    $0 ~ start { skip=1; if (!printed) { print block; print ""; printed=1 }; next }
    skip && /^## / && $0 !~ start { skip=0 }
    !skip { print }
  ' "$CLAUDE_MD" > "$TMP"
  mv "$TMP" "$CLAUDE_MD"
  echo "  Updated Context System in global CLAUDE.md"
else
  # Append after first section or at the end
  TMP=$(mktemp --tmpdir="$(dirname "$CLAUDE_MD")")
  awk -v block="$CONTEXT_BLOCK" '
    BEGIN { inserted=0 }
    !inserted && /^## / && NR > 1 { print ""; print block; print ""; inserted=1 }
    { print }
    END { if (!inserted) { print ""; print block } }
  ' "$CLAUDE_MD" > "$TMP"
  mv "$TMP" "$CLAUDE_MD"
  echo "  Injected Context System into global CLAUDE.md"
fi

echo ""
echo "Foundry installed:"
echo "  Skills:     ${SKILLS_DIR}/foundry-* (${#SKILLS[@]})"
echo "  Agents:     ${AGENTS_DIR}/foundry-* (${#AGENTS[@]})"
echo "  Hooks:      4 hooks in ${SETTINGS_FILE}"
echo "  CLAUDE.md:  Context System injected into ${CLAUDE_MD}"
echo ""
echo "Doc gardening (per project, optional):"
echo "  bash ${SCRIPT_DIR}/scripts/garden-setup.sh /path/to/project              # post-commit only"
echo "  bash ${SCRIPT_DIR}/scripts/garden-setup.sh /path/to/project --cron       # + sweep every 30m"
echo "  bash ${SCRIPT_DIR}/scripts/garden-setup.sh /path/to/project --remove     # uninstall"
echo ""
echo "Restart Claude Code to activate."
echo "Uninstall: bash install.sh --uninstall"
