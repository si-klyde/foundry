#!/usr/bin/env bash
# Standalone quality checker — scans files for common issues
# Usage: check-quality.sh <file1> [file2] ...
# Exit 0 = clean, Exit 1 = issues found

set -euo pipefail

issues=0

for file in "$@"; do
  [ -f "$file" ] || continue

  case "$file" in
    *.ts|*.tsx|*.js|*.jsx)
      # console.log
      cl=$(grep -n 'console\.log' "$file" 2>/dev/null || true)
      if [ -n "$cl" ]; then
        echo "WARN: console.log in $file"
        echo "$cl" | head -5
        issues=$((issues + 1))
      fi

      # debugger
      dbg=$(grep -n 'debugger' "$file" 2>/dev/null || true)
      if [ -n "$dbg" ]; then
        echo "WARN: debugger in $file"
        echo "$dbg" | head -5
        issues=$((issues + 1))
      fi

      # any type (basic heuristic)
      any_type=$(grep -n ': any\b\|<any>' "$file" 2>/dev/null || true)
      if [ -n "$any_type" ]; then
        echo "WARN: 'any' type in $file"
        echo "$any_type" | head -5
        issues=$((issues + 1))
      fi
      ;;
  esac
done

if [ "$issues" -gt 0 ]; then
  echo ""
  echo "${issues} quality issue(s) found"
  exit 1
fi

exit 0
