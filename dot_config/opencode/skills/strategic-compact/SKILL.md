---
name: strategic-compact
description: Suggests manual context compaction at logical task boundaries (after planning, after milestones, before context shifts) instead of arbitrary auto-compaction.
---

# Strategic Compact

Auto-compaction fires mid-task and drops live context. Compact at boundaries instead.

## When

- After exploration, before execution (keep the plan, drop the research).
- After a milestone ships (fresh start for the next phase).
- Before a major context shift (different task, different subsystem).
- Never mid-implementation on related changes.

## How

Before compacting: run `/checkpoint create <phase-name>` so state survives, and state in one paragraph what the next session needs (goal, decisions, open threads). Then compact.

The hooks plugin nudges every ~50 edit/write calls – the nudge tells you *when*, you decide *if*. Checkpoint first, compact second.
