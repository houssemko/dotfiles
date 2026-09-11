---
description: Sync READMEs, guides, and codemaps from source. Derives docs from code, verifies every path and link.
---

# Update Docs: $ARGUMENTS

Delegate to the **doc-updater** subagent (scope in $ARGUMENTS, default: everything stale).

Extract from code (entry points, routes, env vars, scripts, exports), update README/guides plus `codemaps/` (architecture, backend, frontend, data as module/purpose/exports/dependencies tables with timestamps), then validate every path, link, and snippet. Flag rewrites over 30% drift for approval before applying.
