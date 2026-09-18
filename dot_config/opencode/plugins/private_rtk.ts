import type { Plugin } from "@opencode/plugin"
import { execFile } from "node:child_process"

// RTK OpenCode plugin — rewrites commands to use rtk for token savings.
// Requires: rtk >= 0.23.0 in PATH (found: 0.46.0).
//
// V2 port (opencode v2 API). All rewrite logic lives in `rtk rewrite`,
// which is the single source of truth (src/discover/registry.rs).
// To add or change rewrite rules, edit the Rust registry — not this file.

function runFile(cmd: string, args: string[], timeoutMs = 5000): Promise<{ stdout: string }> {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, { timeout: timeoutMs }, (error, stdout) => {
      if (error) reject(error)
      else resolve({ stdout: String(stdout) })
    })
  })
}

export default {
  id: "rtk",
  async setup(ctx) {
    try {
      await runFile("rtk", ["--version"], 5000)
    } catch {
      try {
        await runFile("which", ["rtk"], 5000)
      } catch {
        console.warn("[rtk] rtk binary not found in PATH — plugin disabled")
        return
      }
    }

    await ctx.tool.hook("execute.before", async (event) => {
      const tool = String(event.tool ?? "").toLowerCase()
      if (tool !== "bash" && tool !== "shell") return
      const args = event.input as Record<string, unknown> | undefined
      if (!args || typeof args !== "object") return

      const command = args.command
      if (typeof command !== "string" || !command) return

      try {
        const result = await runFile("rtk", ["rewrite", command], 5000)
        const rewritten = result.stdout.trim()
        if (rewritten && rewritten !== command) {
          args.command = rewritten
        }
      } catch {
        // rtk rewrite failed — pass through unchanged
      }
    })
  },
} satisfies Plugin
