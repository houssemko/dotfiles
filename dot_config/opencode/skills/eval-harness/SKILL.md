---
name: eval-harness
description: Use for eval-driven development. Define capability and regression evals BEFORE implementation, check them during work, report pass@k metrics before shipping.
---

# Eval Harness

Evals are unit tests for the feature: define expected behavior first, track regressions per change.

## Eval file

`~/.config/opencode/memory/evals/<feature>.md` (project override: `./.opencode/evals/`):

```markdown
## EVAL: <feature> | Created: <date>
### Capability evals (can do new things)
- [ ] <observable behavior 1>
### Regression evals (old things still work)
- [ ] <existing behavior 1>
### Success criteria
- pass@3 > 90% capability, 100% regression
```

## Graders

- **Code-based** (preferred): deterministic checks – grep for expected symbols, run relevant tests, run the build. PASS/FAIL, no judgment calls.
- **Model-based**: for open-ended output – score 1-5 on correctness, structure, edge cases, error handling, with reasoning.
- **Human**: flag HIGH-risk changes for manual review with risk level and reason.

## Metrics

- `pass@k`: at least one success in k attempts (target pass@3 > 90%).
- `pass^k`: all k consecutive succeed – for critical paths.

The `/eval` command manages the lifecycle (`define` → `check` → `report`). Log attempts to `<feature>.log`; never ship a feature whose regression evals aren't green.
