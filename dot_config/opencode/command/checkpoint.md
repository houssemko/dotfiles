---
description: Save or compare workflow checkpoints via git plus a local log. Usage: create <name> | verify <name> | list | clear.
---

# Checkpoint: $ARGUMENTS

Parse `$ARGUMENTS` as `<action> <name>` (default action `list`).

- `create <name>`: run `/verify quick` first – refuse on failure. Then `git stash push -m "checkpoint:<name>"` (or commit on a clean tree) and append `date | name | short-SHA` to `~/.config/opencode/memory/checkpoints.log`. Report created.
- `verify <name>`: diff current state against the logged SHA – files added/modified since, test results now vs then, build status. Report `CHECKPOINT COMPARISON` with counts.
- `list`: show all logged checkpoints with name, timestamp, SHA.
- `clear`: drop all but the last 5 entries (ask first).

All state is local files plus git – no services, no dependencies.
