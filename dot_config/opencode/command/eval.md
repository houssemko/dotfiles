---
description: Manage eval-driven development. Usage: define <feature> | check <feature> | report <feature> | list | clean.
---

# Eval: $ARGUMENTS

Follow the `eval-harness` skill. Parse `$ARGUMENTS` as `<action> <feature>`. Eval files live in `~/.config/opencode/memory/evals/<feature>.md` (project overrides in `./.opencode/evals/`).

- `define <feature>`: create the eval file from the capability/regression template and prompt the user to fill in criteria. No code until criteria exist.
- `check <feature>`: verify each capability eval, run tests for regression evals, append results to `<feature>.log`, report `X/Y passing` plus status.
- `report <feature>`: full report with pass@1/pass@3 metrics and a SHIP / NEEDS WORK / BLOCKED recommendation.
- `list`: all eval files with pass counts and status. `clean`: prune old logs (ask first).
