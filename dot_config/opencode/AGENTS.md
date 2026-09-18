<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

## Agent Skills (addyosmani/agent-skills v0.6.10, global)

Skills live in `~/.config/opencode/skills/<name>/SKILL.md` (25 skills). Shared checklists live in `~/.config/opencode/references/` (resolves the `../../references/*.md` links inside skills). Personas live in `~/.config/opencode/agent/`. Commands live in `~/.config/opencode/command/`.

### Core rules

- If a task matches a skill (even ~1% chance), load it with the `skill` tool BEFORE acting and follow its workflow strictly. Never partially apply it.
- Never skip required steps a skill demands (spec, plan, test, verification). "Too small for a skill" / "I'll add tests later" are anti-patterns — ignore them.
- Complements `AGENTS.workflow.md`: that file picks the WHO (planner, architect, security-reviewer, staff-code-reviewer, security-auditor, test-engineer); skills define the HOW.

### Intent → skill mapping

- Vague idea → `interview-me`, then `idea-refine`
- Feature / new functionality → `spec-driven-development`, then `planning-and-task-breakdown`, then `incremental-implementation` + `test-driven-development`
- Planning / breakdown → `planning-and-task-breakdown`
- API / interface / module boundary → `api-and-interface-design`
- UI work → `frontend-ui-engineering`
- Framework/library choice → `source-driven-development` (cite official docs)
- High-stakes / unfamiliar / irreversible decision → `doubt-driven-development`
- Bug / failure / unexpected behavior → `debugging-and-error-recovery`
- Browser / DOM / console / network issue → `browser-testing-with-devtools`
- Refactor / simplification → `code-simplification`
- Code review → `code-review-and-quality` (persona: `staff-code-reviewer`; pre-existing terse `code-reviewer` also available)
- Security (input, auth, secrets, deps, LLM features) → `security-and-hardening` (persona: `security-auditor`)
- Performance concern → `performance-optimization` (persona: `web-performance-auditor` via `/webperf`)
- Tests / coverage → `test-driven-development` (persona: `test-engineer`)
- Quality bar setup / enforcement → `constraint-driven-development` (`CONSTRAINTS.md`)
- Git / commits / versioning → `git-workflow-and-versioning`
- CI/CD / pipelines → `ci-cd-and-automation`
- Docs / ADRs → `documentation-and-adrs`
- Telemetry / logging / alerting → `observability-and-instrumentation`
- Deprecation / migration / removal → `deprecation-and-migration`
- Ship / launch → `shipping-and-launch` (via `/ship` fan-out)
- Unsure which applies → `using-agent-skills` (meta-skill)

### Lifecycle (implicit, no slash needed)

DEFINE → `spec-driven-development` · PLAN → `planning-and-task-breakdown` · BUILD → `incremental-implementation` + `test-driven-development` · VERIFY → `debugging-and-error-recovery` · REVIEW → `code-review-and-quality` · SHIP → `shipping-and-launch`

### Explicit commands (`/spec` etc.)

`/spec` `/plan-breakdown` (pack's `/plan`; pre-existing `/plan` kept as-is) `/build` (`/build auto` = whole plan, one approval) `/test` (pre-existing `/tdd` kept) `/constraints` `/review` (pre-existing `/code-review` kept) `/code-simplify` `/webperf` `/ship` (parallel fan-out: `staff-code-reviewer` + `security-auditor` + `test-engineer`, then merge + rollback plan).

### Notes

- Do NOT copy this repo's root `AGENTS.md`/`CLAUDE.md` into projects — those configure the upstream repo itself, not consumers.
- Renames on install (to avoid overwriting existing config): pack `code-reviewer` persona → `staff-code-reviewer`; pack `/plan` → `/plan-breakdown`. All other names installed verbatim (no prior collisions).
- Source: `/home/houssem/Downloads/agent-skills-0.6.10` (see `agent-skills-install.json` for manifest). To update, re-copy `skills/*` + `references/*.md` and re-apply the two renames above.
