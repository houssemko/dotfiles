import type { Plugin } from "@opencode/plugin"
import { mkdirSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

// everything-claude-code hooks, V2 port (opencode v2 API).
// - Blocks dev servers outside tmux (log access).
// - Blocks stray .md/.txt creation (docs stay in README/guides/codemaps).
// - Nudges strategic compaction every ~50 edits/writes.
// - Logs PR URL + review command after `gh pr create`.

const MEM = join(homedir(), ".config", "opencode", "memory")
const DOC_ALLOW = /(README|CLAUDE|AGENTS|CONTRIBUTING)\.md$|\/codemaps\/|DELETION_LOG\.md$|learned\/.*SKILL\.md$/

function extractResultText(result: unknown): string {
  if (result == null) return ""
  if (typeof result === "string") return result
  if (typeof result !== "object") return String(result)
  const r = result as { content?: unknown; output?: unknown }
  if (typeof r.content === "string") return r.content
  if (Array.isArray(r.content)) {
    return r.content
      .map((c) => {
        if (typeof c === "string") return c
        if (c != null && typeof c === "object" && "text" in c) return String((c as { text: unknown }).text)
        return ""
      })
      .join("\n")
  }
  if (typeof r.output === "string") return r.output
  if (r.output != null) {
    try {
      return JSON.stringify(r.output)
    } catch {
      return String(r.output)
    }
  }
  return ""
}

export default {
  id: "ecc-hooks",
  async setup(ctx) {
    let editCount = 0
    try {
      mkdirSync(MEM, { recursive: true })
      mkdirSync(join(MEM, "evals"), { recursive: true })
    } catch {
      // best effort; commands create dirs as needed
    }

    await ctx.tool.hook("execute.before", (event) => {
      const tool = String(event.tool ?? "").toLowerCase()
      const args = event.input as Record<string, unknown> | undefined
      if (!args || typeof args !== "object") return
      const cmd = args.command
      const file = String(args.file_path ?? args.filePath ?? "")

      if ((tool === "bash" || tool === "shell") && typeof cmd === "string") {
        if (/(npm|pnpm|yarn|bun)(\s+run)?\s+dev\b/.test(cmd) && !process.env.TMUX) {
          throw new Error(
            "[ecc] Dev server must run in tmux for log access. Use: tmux new -s dev -- <cmd>; tmux attach -t dev",
          )
        }
        return
      }

      if (tool === "write" && file && /\.(md|txt)$/.test(file) && !DOC_ALLOW.test(file)) {
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
    })

    await ctx.tool.hook("execute.after", (event) => {
      const tool = String(event.tool ?? "").toLowerCase()
      if (tool !== "bash" && tool !== "shell") return
      if (event.status !== "completed") return
      const out = extractResultText(event.result)
      const m = out.match(/https:\/\/github\.com\/([^/\s]+\/[^/\s]+)\/pull\/(\d+)/)
      if (m) console.error(`[ecc] PR created: ${m[0]} — review with: gh pr review ${m[2]} --repo ${m[1]}`)
    })
  },
} satisfies Plugin
