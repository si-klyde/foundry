#!/usr/bin/env bash
# Generate .foundry/codemap.md for a project
# Usage: generate-codemap.sh [project-dir]

set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

FOUNDRY_DIR=".foundry"
OUTPUT="${FOUNDRY_DIR}/codemap.md"

mkdir -p "$FOUNDRY_DIR"

PROJECT_NAME=$(basename "$(pwd)")
if [ -f "package.json" ] && command -v python3 &>/dev/null; then
  PROJECT_NAME=$(python3 -c "import json; print(json.load(open('package.json')).get('name','$PROJECT_NAME'))" 2>/dev/null || echo "$PROJECT_NAME")
fi

DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

{
  echo "# Codemap — ${PROJECT_NAME}"
  echo "Generated: ${DATE}"
  echo ""

  # File structure
  echo "## File Structure"
  echo '```'
  if command -v tree &>/dev/null; then
    tree -L 3 -I 'node_modules|.git|.foundry|dist|build|coverage|.next|__pycache__|target' --dirsfirst 2>/dev/null | head -80
  else
    find . -maxdepth 3 \
      -not -path './node_modules/*' \
      -not -path './.git/*' \
      -not -path './.foundry/*' \
      -not -path './dist/*' \
      -not -path './build/*' \
      -not -name '*.map' \
      | sort | head -80
  fi
  echo '```'
  echo ""

  # Key exports
  if ls src/**/*.ts &>/dev/null 2>&1 || ls src/*.ts &>/dev/null 2>&1; then
    echo "## Key Exports"
    echo '```'
    grep -rn '^export' src/ --include='*.ts' --include='*.tsx' 2>/dev/null | head -50 || true
    echo '```'
    echo ""
  fi

  # Entry points
  echo "## Entry Points"
  for entry in "src/index.ts" "src/main.ts" "src/app.ts" "src/server.ts" "index.ts" "main.ts"; do
    if [ -f "$entry" ]; then
      echo "- \`${entry}\`"
    fi
  done
  echo ""

  # Recent activity
  if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    echo "## Recent Activity"
    echo '```'
    git log --oneline -10 2>/dev/null || true
    echo '```'
    echo ""

    # Hot files (most changed recently)
    echo "## Hot Files (most changed in last 20 commits)"
    echo '```'
    git log --name-only --pretty=format: -20 2>/dev/null | sort | uniq -c | sort -rn | head -15 | grep -v '^$' || true
    echo '```'
    echo ""
  fi

  # Dependencies
  if [ -f "package.json" ] && command -v python3 &>/dev/null; then
    echo "## Dependencies"
    echo '```'
    python3 -c "
import json
p = json.load(open('package.json'))
deps = p.get('dependencies', {})
dev = p.get('devDependencies', {})
if deps:
    print('Runtime:')
    for k,v in sorted(deps.items()):
        print(f'  {k}: {v}')
if dev:
    print('Dev:')
    for k,v in sorted(dev.items()):
        print(f'  {k}: {v}')
" 2>/dev/null || true
    echo '```'
  fi

} > "$OUTPUT"

echo "Codemap written to ${OUTPUT}"
wc -l "$OUTPUT"
