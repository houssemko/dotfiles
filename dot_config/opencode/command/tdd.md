---
description: Enforce test-driven development. Writes failing tests FIRST, then minimal implementation, then refactors. Ensures 80%+ coverage.
---

# TDD: $ARGUMENTS

Delegate to the **tdd-guide** subagent with the task above. Follow the `tdd-workflow` skill.

Cycle: RED (failing test, confirm it fails for the right reason) → GREEN (minimal code to pass) → IMPROVE (refactor, tests stay green) → verify 80%+ coverage on touched files. Fix implementation, not tests, unless a test itself is wrong. Use the repo's existing test runner – no new frameworks.
