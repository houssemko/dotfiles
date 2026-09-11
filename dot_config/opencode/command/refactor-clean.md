---
description: Safely identify and remove dead code with test verification. Logs all deletions, never touches public APIs without approval.
---

# Refactor Clean: $ARGUMENTS

Delegate to the **refactor-cleaner** subagent (scope in $ARGUMENTS, default: whole repo).

Remove one category at a time (unused deps → exports → files → duplicates), running build + tests after each. Log deletions to `DELETION_LOG.md`. RISKY items (public API, shared utils) need explicit approval. Revert the category if tests fail.
