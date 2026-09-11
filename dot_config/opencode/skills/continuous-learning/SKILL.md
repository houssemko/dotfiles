---
name: continuous-learning
description: Use to extract reusable patterns from a session (error fixes, debugging techniques, workarounds, project conventions) and save them as learned skills.
---

# Continuous Learning

One pattern per skill. Only patterns that save future time – never trivial typos or one-off outages.

## Detect

Worth extracting: error → root cause → fix pairs, non-obvious debugging sequences, library quirks and workarounds, corrections the user had to repeat, project conventions discovered mid-session.

## Save

Draft as: name / problem / solution / example / when-to-use. Present the draft, save only on explicit approval to `~/.config/opencode/skills/learned/<pattern-name>/SKILL.md` (frontmatter `name` + `description` required, third person, trigger keywords first).

## Recall

Learned skills are auto-loaded like any other skill. At session start, check `~/.config/opencode/skills/learned/` for anything relevant to the task at hand.

The `/learn` command runs mid-session extraction. Skipped: automatic end-of-session hooks – run `/learn` deliberately, add automation when manual extraction proves too easy to forget.
