---
description: Run verification gates (build, types, lint, tests, secrets) and report PASS/FAIL with readiness verdict. Modes: quick, full, pre-commit, pre-pr.
---

# Verify: $ARGUMENTS

Follow the `verification-loop` skill. Mode from $ARGUMENTS (default `full`):

- `quick`: build + type check only.
- `full`: build → types → lint → full test suite with coverage → secrets/console.log grep → `git diff --stat` review.
- `pre-commit`: quick plus lint and affected tests.
- `pre-pr`: full plus security-reviewer pass on the diff.

Stop at the first failing gate for `quick`; run all gates and aggregate for `full`. Output the verification report with `Ready for PR: YES/NO` and fix suggestions for failures.
