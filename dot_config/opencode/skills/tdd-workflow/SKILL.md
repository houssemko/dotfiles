---
name: tdd-workflow
description: Use when writing features, fixing bugs, or refactoring. Enforces tests-first RED-GREEN-IMPROVE cycle with 80%+ unit, integration, and E2E coverage.
---

# TDD Workflow

Tests BEFORE code. Complements the `test-master` skill (consult it for framework specifics).

## Cycle

1. **RED** – write one failing test (unit for functions, integration for endpoints, E2E for flows). Run it, confirm it fails for the right reason.
2. **GREEN** – minimal implementation to pass. No extra scope.
3. **IMPROVE** – refactor with tests green: dedupe, rename, simplify.
4. **Coverage** – 80%+ on touched files: edge cases, error paths, boundaries.

## Rules

- Fix implementation, not tests (unless the test is wrong).
- One behavior per test, independent and deterministic.
- Use the repo's existing runner and fixtures. No new test frameworks.
- The `/tdd` command runs this workflow; the `tdd-guide` agent enforces it via delegation.
