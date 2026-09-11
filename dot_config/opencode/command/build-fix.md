---
description: Fix build and type errors incrementally with minimal diffs. Stops on decisions that need a human (version conflicts, new packages).
---

# Build Fix: $ARGUMENTS

Delegate to the **build-error-resolver** subagent with the error output or failure context in $ARGUMENTS (if empty, run the repo build first to collect errors).

One minimal fix per error, re-verify after each, report X/Y fixed plus files touched. Never install packages or change architecture to fix a build – flag those for approval instead.
