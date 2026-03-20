#!/usr/bin/env bash
# Doc Gardening — scans git diffs, auto-updates AGENTS.md files via claude --print
#
# Modes:
#   post-commit:  garden-docs.sh /path/to/project          (diffs HEAD~1..HEAD)
#   cron/sweep:   garden-docs.sh /path/to/project --sweep   (diffs since last garden)
#
# Post-commit mode diffs only the latest commit — fast, immediate.
# Sweep mode diffs everything since last run — catches rebases, squashes, pulls.

set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

MODE="post-commit"
if [ "${2:-}" = "--sweep" ]; then
  MODE="sweep"
fi

MARKER_FILE=".foundry/.last-garden"
LOCK_FILE=".foundry/.garden-lock"

# Prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    exit 0
  fi
  rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

mkdir -p .foundry

CURRENT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
if [ -z "$CURRENT_SHA" ]; then
  exit 0
fi

# Determine diff range based on mode
if [ "$MODE" = "post-commit" ]; then
  # Always diff the commit that just landed
  LAST_SHA="HEAD~1"
  # Guard: if this is the initial commit, no parent exists
  if ! git rev-parse HEAD~1 &>/dev/null; then
    echo "$CURRENT_SHA" > "$MARKER_FILE"
    exit 0
  fi
else
  # Sweep: diff since last garden run
  if [ -f "$MARKER_FILE" ]; then
    LAST_SHA=$(cat "$MARKER_FILE")
    if ! git cat-file -e "$LAST_SHA" 2>/dev/null; then
      LAST_SHA=$(git rev-list --max-parents=0 HEAD 2>/dev/null | tail -1)
    fi
  else
    LAST_SHA="HEAD~1"
  fi
  # No new commits since last sweep
  if [ "$LAST_SHA" = "$CURRENT_SHA" ]; then
    exit 0
  fi
fi

# Get changed files (excluding AGENTS.md and decisions.md to avoid loops)
CHANGED_FILES=$(git diff --name-only "$LAST_SHA" "$CURRENT_SHA" 2>/dev/null | grep -v 'AGENTS\.md$' | grep -v 'decisions\.md$' || true)

if [ -z "$CHANGED_FILES" ]; then
  echo "$CURRENT_SHA" > "$MARKER_FILE"
  exit 0
fi

# Find all AGENTS.md files in the repo
AGENTS_FILES=$(find . -name 'AGENTS.md' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null || true)

if [ -z "$AGENTS_FILES" ]; then
  echo "$CURRENT_SHA" > "$MARKER_FILE"
  exit 0
fi

# Group changed files by directory, match to nearest AGENTS.md
declare -A SCOPE_MAP

for changed in $CHANGED_FILES; do
  dir=$(dirname "$changed")
  check_dir="$dir"
  while [ "$check_dir" != "." ] && [ "$check_dir" != "/" ]; do
    if [ -f "$check_dir/AGENTS.md" ]; then
      SCOPE_MAP["$check_dir/AGENTS.md"]+="$changed"$'\n'
      break
    fi
    check_dir=$(dirname "$check_dir")
  done
  if [ "$check_dir" = "." ] || [ "$check_dir" = "/" ]; then
    if [ -f "AGENTS.md" ]; then
      SCOPE_MAP["AGENTS.md"]+="$changed"$'\n'
    fi
  fi
done

if [ ${#SCOPE_MAP[@]} -eq 0 ]; then
  echo "$CURRENT_SHA" > "$MARKER_FILE"
  exit 0
fi

# For each AGENTS.md with changes in scope, ask claude to update it
UPDATED=0
for agents_md in "${!SCOPE_MAP[@]}"; do
  scope_files="${SCOPE_MAP[$agents_md]}"
  scope_dir=$(dirname "$agents_md")

  DIFF=$(echo "$scope_files" | xargs -I{} git diff "$LAST_SHA" "$CURRENT_SHA" -- {} 2>/dev/null | head -500)

  if [ -z "$DIFF" ]; then
    continue
  fi

  CURRENT_CONTENT=$(cat "$agents_md" 2>/dev/null || echo "")

  PROMPT="You are a doc gardener. Your job is to keep AGENTS.md files up to date.

AGENTS.md files contain ONLY:
- Gotchas (things that will bite you)
- Patterns (how things are done here)
- Pointers to decisions.md for architecture choices
- NO code snippets, NO architecture explanations, NO prose

Here is the current $agents_md:
---
$CURRENT_CONTENT
---

Here are the recent changes in its scope ($scope_dir/):
---
$DIFF
---

Changed files: $scope_files

If the diff introduces new gotchas, patterns, or invalidates existing entries, output the COMPLETE updated AGENTS.md content. If no updates are needed, output exactly: NO_CHANGES_NEEDED

Rules:
- Keep it terse. Every line earns its tokens.
- Do not add code snippets.
- Do not explain architecture — that's what the code is for.
- Only add entries that would save a future developer from a mistake or confusion.
- Remove entries that the diff makes obsolete."

  RESULT=$(echo "$PROMPT" | claude --print -p --model sonnet --max-turns 1 2>/dev/null || echo "GARDEN_ERROR")

  if [ "$RESULT" = "GARDEN_ERROR" ] || [ "$RESULT" = "NO_CHANGES_NEEDED" ]; then
    continue
  fi

  # Validate result looks like markdown
  if echo "$RESULT" | head -1 | grep -qE '^#|^[A-Za-z]'; then
    echo "$RESULT" > "$agents_md"
    UPDATED=$((UPDATED + 1))
    git add "$agents_md" 2>/dev/null || true
  fi
done

if [ $UPDATED -gt 0 ]; then
  git commit -m "docs: garden AGENTS.md ($UPDATED files updated)" --no-verify 2>/dev/null || true
fi

echo "$CURRENT_SHA" > "$MARKER_FILE"
