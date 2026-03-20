---
name: foundry-benchmark
description: >
  Compare session effectiveness with and without Foundry. Tracks metrics like verification pass rate,
  commit frequency, context reloads. Trigger: "benchmark", "compare", "how is foundry doing?".
version: 0.1.0
---

# /foundry-benchmark — Session Effectiveness Comparison

## What it does

Collects and compares metrics to measure Foundry's impact on session quality.

## Metrics Tracked

| Metric | Source | Better = |
|--------|--------|----------|
| Verification pass rate | session-log.jsonl | Higher |
| Commits per session | git log | Higher (incremental) |
| Avg edits between checkpoints | .change-count resets | Lower |
| Context reloads (post-compact) | session-log.jsonl | Fewer |
| Quality issues caught | post-tool-use warnings | More caught = better |
| Plan completion rate | active-plan.json | Higher |

## Steps

1. **Collect current session metrics** from:
   - `.foundry/session-log.jsonl` — tool call count, files touched
   - `git log --since="today"` — commits this session
   - `foundry-progress.json` — tasks completed
   - Active plan — task completion rate

2. **Compare to baseline** (if `.foundry/benchmarks/` has prior data):
   - Load previous session metrics
   - Calculate deltas

3. **Report:**
   ```
   ## Session Metrics
   - Duration: ~45min (estimated from log timestamps)
   - Tool calls: 47 (32 edits, 15 reads)
   - Files touched: 8
   - Commits: 4 (avg 12 edits/commit)
   - Verification: 4/4 pass (100%)
   - Quality catches: 2 console.log, 1 any type
   - Plan: 3/5 tasks complete (60%)
   ```

4. **Save metrics** to `.foundry/benchmarks/<date>.json` for future comparison.

## Important

- Metrics are approximate — session-log timing isn't perfectly accurate
- Compare sessions of similar complexity for meaningful results
- This is for self-improvement, not judgment
