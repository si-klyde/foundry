#!/usr/bin/env bash
# Set up doc gardening for a project directory.
#
# Usage:
#   garden-setup.sh [project-dir]                    # post-commit hook only
#   garden-setup.sh [project-dir] --cron [--interval 30]  # also add cron sweep
#   garden-setup.sh [project-dir] --remove           # remove everything
#
# Post-commit hook: fires immediately on every commit (fast, single-commit diff)
# Cron sweep: catches rebases, squashes, pulls, manual edits (configurable interval)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
GARDEN_SCRIPT="${SCRIPT_DIR}/garden-docs.sh"

# First positional arg is project dir, default to cwd
PROJECT_DIR="."
if [ $# -gt 0 ] && [[ ! "$1" =~ ^-- ]]; then
  PROJECT_DIR="$1"
  shift
fi
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

CRON=false
INTERVAL=30
REMOVE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --cron) CRON=true; shift ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --remove) REMOVE=true; shift ;;
    *) shift ;;
  esac
done

HOOK_FILE="${PROJECT_DIR}/.git/hooks/post-commit"
HOOK_MARKER="# foundry-garden"
CRON_TAG="# foundry-garden:${PROJECT_DIR}"

# --- Remove ---
if [ "$REMOVE" = true ]; then
  # Remove post-commit hook (or just the foundry line if other hooks exist)
  if [ -f "$HOOK_FILE" ]; then
    OTHER_LINES=$(grep -v "$HOOK_MARKER" "$HOOK_FILE" | grep -v '^#!/' | grep -v '^$' || true)
    if [ -z "$OTHER_LINES" ]; then
      rm -f "$HOOK_FILE"
    else
      grep -v "$HOOK_MARKER" "$HOOK_FILE" > "${HOOK_FILE}.tmp"
      mv "${HOOK_FILE}.tmp" "$HOOK_FILE"
    fi
    echo "Removed post-commit hook"
  fi

  # Remove cron entry
  if crontab -l 2>/dev/null | grep -q "foundry-garden:${PROJECT_DIR}"; then
    crontab -l 2>/dev/null | grep -v "foundry-garden:${PROJECT_DIR}" | crontab -
    echo "Removed cron sweep"
  fi

  echo "Doc gardening removed for ${PROJECT_DIR}"
  exit 0
fi

# --- Validate ---
if [ ! -d "${PROJECT_DIR}/.git" ]; then
  echo "Error: ${PROJECT_DIR} is not a git repo"
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "Error: claude CLI not in PATH"
  exit 1
fi

# --- Install post-commit hook ---
mkdir -p "$(dirname "$HOOK_FILE")"

if [ -f "$HOOK_FILE" ]; then
  # Remove old foundry line if present
  grep -v "$HOOK_MARKER" "$HOOK_FILE" > "${HOOK_FILE}.tmp" || true
  mv "${HOOK_FILE}.tmp" "$HOOK_FILE"
else
  echo '#!/usr/bin/env bash' > "$HOOK_FILE"
fi

echo "${GARDEN_SCRIPT} ${PROJECT_DIR} & ${HOOK_MARKER}" >> "$HOOK_FILE"
chmod +x "$HOOK_FILE"

echo "Post-commit hook installed:"
echo "  Fires on every commit, diffs HEAD~1..HEAD"
echo "  Runs in background (non-blocking)"

# --- Install cron sweep (optional) ---
if [ "$CRON" = true ]; then
  CRON_CMD="*/${INTERVAL} * * * * ${GARDEN_SCRIPT} ${PROJECT_DIR} --sweep ${CRON_TAG}"
  (crontab -l 2>/dev/null | grep -v "foundry-garden:${PROJECT_DIR}"; echo "$CRON_CMD") | crontab -

  echo ""
  echo "Cron sweep enabled:"
  echo "  Interval: every ${INTERVAL} minutes"
  echo "  Catches rebases, pulls, manual edits"
fi

echo ""
echo "Garden script: ${GARDEN_SCRIPT}"
echo "Remove:        $(basename "$0") ${PROJECT_DIR} --remove"
