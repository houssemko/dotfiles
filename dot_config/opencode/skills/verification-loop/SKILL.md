---
name: verification-loop
description: Use after features, refactors, or before PRs. Runs ordered quality gates (build, types, lint, tests, secrets, diff review) and reports PASS/FAIL with PR readiness.
---

# Verification Loop

Run gates in order with the repo's own tooling. No new dependencies.

## Gates

1. **Build** – repo build command. Fail → STOP, fix first.
2. **Types** – type checker (`tsc --noEmit`, `pyright`, etc.). Report `file:line` for all errors.
3. **Lint** – repo linter. Report warnings and errors.
4. **Tests** – full suite with coverage. Report passed/total plus coverage % (target 80%+).
5. **Secrets/logs** – grep source for `api[_-]?key|password|secret|token` and stray `console.log`/`print`.
6. **Diff review** – `git diff --stat` plus per-file skim for unintended changes and missing error handling.

## Report

```
VERIFICATION: [PASS/FAIL]
Build: [OK/FAIL] | Types: [OK/X errors] | Lint: [OK/X issues]
Tests: [X/Y passed, Z% coverage] | Secrets: [OK/X found] | Logs: [OK/X]
Ready for PR: [YES/NO] + issues with fix suggestions
```

The `/verify` command runs this (modes: `quick` = gates 1-2, `full` = all, `pre-pr` = all plus security-reviewer). For long sessions, re-run after each milestone, not just at the end.
