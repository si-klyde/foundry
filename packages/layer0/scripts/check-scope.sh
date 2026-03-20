#!/usr/bin/env bash
# Scope checker — validates a file is within active plan's relevant files
# Usage: check-scope.sh <project-dir> <file-path>
# Exit 0 = in scope or no plan, Exit 1 = out of scope

set -euo pipefail

PROJECT_DIR="${1:-.}"
FILE_PATH="${2:-}"

[ -z "$FILE_PATH" ] && exit 0

ACTIVE_PLAN="${PROJECT_DIR}/.foundry/active-plan.json"
[ ! -f "$ACTIVE_PLAN" ] && exit 0

command -v python3 &>/dev/null || exit 0

python3 -c "
import json, os, sys

plan_meta = json.load(open('${ACTIVE_PLAN}'))
plan_file = plan_meta.get('plan_file', '')
if not plan_file:
    sys.exit(0)

plan_path = os.path.join('${PROJECT_DIR}', plan_file)
if not os.path.exists(plan_path):
    sys.exit(0)

content = open(plan_path).read()
relevant_files = set()
for line in content.split('\n'):
    if '(files:' in line:
        start = line.index('(files:') + 7
        end = line.index(')', start)
        files = [f.strip() for f in line[start:end].split(',')]
        relevant_files.update(files)

if not relevant_files:
    sys.exit(0)

rel_path = os.path.relpath('${FILE_PATH}', '${PROJECT_DIR}')
in_scope = any(rel_path == f or rel_path.endswith('/' + f) for f in relevant_files)

if not in_scope:
    print(f'OUT OF SCOPE: {rel_path}')
    print(f'Relevant files: {\", \".join(sorted(relevant_files))}')
    sys.exit(1)
"
