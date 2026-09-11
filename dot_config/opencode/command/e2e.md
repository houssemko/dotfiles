---
description: Generate and run Playwright E2E tests for critical user flows. Captures screenshots/videos/traces on failure, quarantines flaky specs.
---

# E2E: $ARGUMENTS

Delegate to the **e2e-runner** subagent with the flow or area in $ARGUMENTS (if empty, cover the repo's critical user journeys).

One spec per flow, stable selectors, seeded test data. Report X/Y passed with artifact paths for failures; confirmed-flaky specs go to `quarantine/` with a dated note, never committed as passing.
