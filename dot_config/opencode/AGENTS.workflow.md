# Workflow Rules

Always-follow guidelines ported from everything-claude-code, trimmed to zero-dependency practices. Complements `AGENTS.caveman.md`.

## Delegation

Complex feature or refactor → **planner** first, implement only after approval. Architecture decision → **architect** (ADR for significant calls). Code written → **code-reviewer** immediately. Auth/input/endpoints/secrets → **security-reviewer** before commit. Build red → **build-error-resolver**. Critical flows → **e2e-runner**. Docs stale → **doc-updater**. Run independent reviews in parallel.

## Slash commands

`/plan` plan-first, `/tdd` tests-first, `/code-review`, `/build-fix`, `/refactor-clean`, `/e2e`, `/verify` (quick/full/pre-commit/pre-pr), `/checkpoint` (create/verify/list/clear), `/learn`, `/eval` (define/check/report/list), `/update-docs`.

## Coding style

Immutability: new objects, never mutate. Many small files (200-400 lines typical, 800 max), functions <50 lines, nesting ≤4. No emojis in code. No `console.log` in prod code. Validate all input at boundaries; parameterized queries only; handle errors with context.

## Testing

TDD: RED → GREEN → IMPROVE. 80%+ coverage on touched code (unit + integration + E2E for flows). Fix implementation, not tests.

## Security (before ANY commit)

No hardcoded secrets (env vars, fail fast if missing). All input validated. No injection/XSS/CSRF gaps. Rate-limit endpoints. Error messages leak nothing. Secret found → STOP, rotate, then continue review.

## Git

Conventional commits (`feat/fix/refactor/docs/test/chore/perf/ci`). Never commit to main directly; branch, verify, PR with test plan. Review full `git diff` before push.

## Modes (contexts)

- **dev**: code first, explain after. Working over perfect. Test after changes, atomic commits.
- **review**: read fully before commenting, severity-ordered, suggest fixes not just problems.
- **research**: read widely, document findings, no code until understanding is clear.

State the mode in one line when switching (`Mode: dev/review/research`), then behave accordingly.

## Performance / context

Heavy reasoning for architecture, light for single-file edits. `/checkpoint` + compact at task boundaries (see `strategic-compact` skill), never mid-implementation. Keep active tool surface lean: under ~80 tools per project.
