---
description: Security and quality review of uncommitted changes. Reports critical/high/medium issues with fixes and an approve/warn/block verdict.
---

# Code Review: $ARGUMENTS

Delegate to the **code-reviewer** subagent (pull in **security-reviewer** for auth, input handling, endpoints, or secrets).

Scope defaults to `git diff HEAD` – or the files named in $ARGUMENTS. Report by severity with `file:line` and minimal fix snippets. Verdict: APPROVE (no critical/high), WARN (medium only), BLOCK (critical/high present).
