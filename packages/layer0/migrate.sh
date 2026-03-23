#!/usr/bin/env bash
# Foundry migration — removes legacy install.sh artifacts, prepares for plugin install
# Run once: bash packages/layer0/migrate.sh
# Then in Claude Code: /plugin marketplace add ./path/to/foundry
#                      /plugin install foundry@foundry

set -euo pipefail

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

CONTEXT_BLOCK_START="## Context System"

echo "Foundry migration: removing legacy install artifacts..."
echo ""

CHANGED=false

# 1. Remove copied skills
SKILL_COUNT=0
for skill in "${SKILLS[@]}"; do
  if [ -d "${SKILLS_DIR}/${skill}" ]; then
    rm -rf "${SKILLS_DIR}/${skill}"
    ((SKILL_COUNT++))
  fi
done
if [ "$SKILL_COUNT" -gt 0 ]; then
  echo "  Removed ${SKILL_COUNT} skills from ${SKILLS_DIR}"
  CHANGED=true
fi

# 2. Remove copied agents
AGENT_COUNT=0
for agent in "${AGENTS[@]}"; do
  if [ -f "${AGENTS_DIR}/foundry-${agent}.md" ]; then
    rm -f "${AGENTS_DIR}/foundry-${agent}.md"
    ((AGENT_COUNT++))
  fi
done
if [ "$AGENT_COUNT" -gt 0 ]; then
  echo "  Removed ${AGENT_COUNT} agents from ${AGENTS_DIR}"
  CHANGED=true
fi

# 3. Remove Foundry hooks from settings.json (preserve non-Foundry hooks)
if [ -f "$SETTINGS_FILE" ] && command -v jq &>/dev/null; then
  # Check if any run-hook.cmd entries exist
  if jq -e '.hooks // {} | to_entries[] | .value[] | .hooks[] | select((.command // "") | test("run-hook\\.cmd"))' "$SETTINGS_FILE" &>/dev/null; then
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
    echo "  Removed 4 Foundry hooks from settings.json"
    CHANGED=true
  fi

  # Remove stale enabledPlugins entry if present
  if jq -e '.enabledPlugins["foundry@foundry-local"] // empty' "$SETTINGS_FILE" &>/dev/null; then
    TMP=$(mktemp --tmpdir="$(dirname "$SETTINGS_FILE")")
    jq 'del(.enabledPlugins["foundry@foundry-local"])' "$SETTINGS_FILE" > "$TMP"
    mv "$TMP" "$SETTINGS_FILE"
    echo "  Removed stale foundry@foundry-local from enabledPlugins"
    CHANGED=true
  fi
fi

# 4. Remove Context System block from global CLAUDE.md
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
  echo "  Removed Context System block from global CLAUDE.md"
  CHANGED=true
fi

# 5. Clean up stale plugin cache
if [ -d "${CLAUDE_DIR}/plugins/cache/foundry-local" ]; then
  rm -rf "${CLAUDE_DIR}/plugins/cache/foundry-local"
  echo "  Removed stale foundry-local plugin cache"
  CHANGED=true
fi

echo ""
if [ "$CHANGED" = true ]; then
  echo "Legacy artifacts removed."
else
  echo "No legacy artifacts found — clean install."
fi

echo ""
echo "Next steps (inside Claude Code):"
echo "  1. /plugin marketplace add /path/to/foundry"
echo "  2. /plugin install foundry@foundry"
echo ""
echo "Or test locally:"
echo "  claude --plugin-dir /path/to/foundry/packages/layer0"
