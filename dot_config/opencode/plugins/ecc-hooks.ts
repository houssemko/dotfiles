import type { Plugin } from "@opencode-ai/plugin"
import { existsSync, mkdirSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

// everything-claude-code hooks, zero-dependency port (node builtins only).
// - Blocks dev servers outside tmux (log access).
// - Blocks stray .md/.txt creation (docs stay in README/guides/codemaps).
// - Nudges strategic compaction every ~50 edits/writes.
// - Logs PR URL + review command after `gh pr create`.
// Skipped (need deps/services): prettier auto-format, tsc-after-edit,
// package-manager detection, MCP configs, Node script hooks.

const MEM = join(homedir(), ".config", "opencode", "memory")
const DOC_ALLOW = /(README|CLAUDE|AGENTS|CONTRIBUTING)\.md$|\/codemaps\/|DELETION_LOG\.md$|learned\/.*SKILL\.md$/
let editCount = 0

export default (async () => {
  try {
    mkdirSync(MEM, { recursive: true })
    mkdirSync(join(MEM, "evals"), { recursive: true })
  } catch {
    // best effort; commands create dirs as needed
  }

  return {
    "tool.execute.before": async (input, output) => {
      const tool = String(input?.tool ?? "").toLowerCase()
      const args = output?.args as Record<string, unknown> | undefined
      if (!args || typeof args !== "object") return
      const cmd = (args as Record<string, unknown>).command
      const file = String(
        (args as Record<string, unknown>).file_path ??
          (args as Record<string, unknown>).filePath ??
          "",
      )

      if ((tool === "bash" || tool === "shell") && typeof cmd === "string") {
        if (/(npm|pnpm|yarn|bun)(\s+run)?\s+dev\b/.test(cmd) && !process.env.TMUX) {
          throw new Error(
            "[ecc] Dev server must run in tmux for log access. Use: tmux new -s dev -- <cmd>; tmux attach -t dev",
          )
        }
        return
      }

      if ((tool === "write") && file && /\.(md|txt)$/.test(file) && !DOC_ALLOW.test(file)) {
        throw new Error(
          `[ecc] Blocked stray doc file: ${file}. Put docs in README.md, guides, codemaps/, or a learned skill instead.`,
        )
      }

      if (tool === "edit" || tool === "write") {
        editCount++
        if (editCount === 50 || (editCount > 50 && (editCount - 50) % 25 === 0)) {
          console.error(
            `[ecc] ${editCount} edits this session. Boundary reached? /checkpoint create <phase>, then compact (see strategic-compact skill).`,
          )
        }
      }
    },

    "tool.execute.after": async (input) => {
      const tool = String(input?.tool ?? "").toLowerCase()
      if (tool !== "bash" && tool !== "shell") return
      const out = String((input as Record<string, unknown>)?.output ?? "")
      const m = out.match(/https:\/\/github\.com\/([^/\s]+\/[^/\s]+)\/pull\/(\d+)/)
      if (m) console.error(`[ecc] PR created: ${m[0]} — review with: gh pr review ${m[2]} --repo ${m[1]}`)
    },
  }
}) satisfies Plugin
