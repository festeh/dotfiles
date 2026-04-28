import { Variable } from "astal"
import GLib from "gi://GLib"
import Gio from "gi://Gio"
import Hyprland from "gi://AstalHyprland"

const SESSIONS_DIR = GLib.get_home_dir() + "/.cache/ags-claude/sessions"
const STALE_THRESHOLD_MS = 300000

export interface ClaudeSession {
  session_id: string
  state: "idle" | "running" | "waiting" | "compacting" | "unknown"
  action: string
  cwd: string
  transcript: string
  updated_at: string
  prompt?: string
  tool_name?: string
  tool_input?: Record<string, any>
  tool_count: number
  agent_type?: string
  error?: string
  notification_message?: string
  last_assistant_message?: string
  claude_pid?: number
  window_address?: string
}

function basename(path: string): string {
  if (!path) return "claude"
  const idx = path.lastIndexOf("/")
  return idx >= 0 ? path.slice(idx + 1) || path : path
}

function isStale(session: ClaudeSession): boolean {
  if (session.state === "idle") return false
  try {
    const updated = new Date(session.updated_at).getTime()
    return Date.now() - updated > STALE_THRESHOLD_MS
  } catch { return true }
}

function normalizeSession(raw: any): ClaudeSession {
  return {
    session_id: raw.session_id || "",
    state: raw.state || "unknown",
    action: raw.action || "",
    cwd: raw.cwd || "",
    transcript: raw.transcript || "",
    updated_at: raw.updated_at || "",
    prompt: raw.prompt || undefined,
    tool_name: raw.tool_name || undefined,
    tool_input: raw.tool_input || undefined,
    tool_count: typeof raw.tool_count === "number" ? raw.tool_count : 0,
    agent_type: raw.agent_type || undefined,
    error: raw.error || undefined,
    notification_message: raw.notification_message || undefined,
    last_assistant_message: raw.last_assistant_message || undefined,
    claude_pid: typeof raw.claude_pid === "number" ? raw.claude_pid : undefined,
    window_address: typeof raw.window_address === "string" ? raw.window_address : undefined,
  }
}

function readSessions(): ClaudeSession[] {
  if (!GLib.file_test(SESSIONS_DIR, GLib.FileTest.IS_DIR)) return []
  const sessions: ClaudeSession[] = []
  try {
    const dir = Gio.File.new_for_path(SESSIONS_DIR)
    const enumerator = dir.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null)
    let info: Gio.FileInfo | null
    while ((info = enumerator.next_file(null)) !== null) {
      const name = info.get_name()
      if (!name.endsWith(".json")) continue
      const path = `${SESSIONS_DIR}/${name}`
      try {
        const [ok, content] = GLib.file_get_contents(path)
        if (!ok) continue
        const text = new TextDecoder().decode(content)
        const session = normalizeSession(JSON.parse(text))
        // Prune sessions whose claude process is gone (kitty kill, crash).
        // window_address alone isn't safe: Hyprland recycles addresses, so a
        // dead session can resurface on whichever client got the pointer next.
        if (session.claude_pid && !GLib.file_test(`/proc/${session.claude_pid}`, GLib.FileTest.IS_DIR)) {
          try { Gio.File.new_for_path(path).delete(null) } catch {}
          continue
        }
        sessions.push(session)
      } catch {}
    }
    enumerator.close(null)
  } catch { return [] }
  return sessions
    .filter(s => !isStale(s))
    .sort((a, b) => new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime())
}

function sameSessions(a: ClaudeSession[], b: ClaudeSession[]): boolean {
  if (a.length !== b.length) return false
  for (let i = 0; i < a.length; i++) {
    if (a[i].session_id !== b[i].session_id) return false
    if (a[i].state !== b[i].state) return false
    if (a[i].cwd !== b[i].cwd) return false
    if (a[i].action !== b[i].action) return false
    if (a[i].tool_count !== b[i].tool_count) return false
    if (a[i].tool_name !== b[i].tool_name) return false
    if (a[i].agent_type !== b[i].agent_type) return false
    if (a[i].error !== b[i].error) return false
    if (a[i].claude_pid !== b[i].claude_pid) return false
    if (a[i].window_address !== b[i].window_address) return false
  }
  return true
}

export const claudeSessions = Variable<ClaudeSession[]>([])

function refreshSessions(): void {
  const fresh = readSessions()
  if (!sameSessions(claudeSessions.get(), fresh)) {
    claudeSessions.set(fresh)
  }
}

GLib.mkdir_with_parents(SESSIONS_DIR, 0o755)

const dirFile = Gio.File.new_for_path(SESSIONS_DIR)
const monitor = dirFile.monitor_directory(Gio.FileMonitorFlags.NONE, null)
monitor.set_rate_limit(50)
monitor.connect("changed", (_m, file, _other, _event) => {
  const path = file.get_path()
  if (path && path.endsWith(".json")) refreshSessions()
})

// Liveness tick: catches sessions whose claude died without SessionEnd
// (Ctrl+C, crash). FileMonitor handles file changes; this only exists to
// notice dead /proc/<pid> entries when nothing else fires.
GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
  refreshSessions()
  return GLib.SOURCE_CONTINUE
})

// Window died -> session that pointed to it is dead too. Refresh now so the
// pill disappears immediately rather than waiting for the slow tick.
Hyprland.get_default().connect("client-removed", () => refreshSessions())

refreshSessions()

// Ticker that drives the live idle-pill timer.
export const idleTick = Variable<number>(0)
GLib.timeout_add(GLib.PRIORITY_DEFAULT, 5000, () => {
  idleTick.set(idleTick.get() + 1)
  return GLib.SOURCE_CONTINUE
})

export function sessionDisplayName(session: ClaudeSession): string {
  return basename(session.cwd)
}

export function formatElapsed(session: ClaudeSession): string {
  try {
    const updated = new Date(session.updated_at).getTime()
    const elapsed = Math.floor((Date.now() - updated) / 1000)
    if (elapsed < 60) return `${elapsed}s`
    if (elapsed < 3600) return `${Math.floor(elapsed / 60)}m`
    return `${Math.floor(elapsed / 3600)}h ${Math.floor((elapsed % 3600) / 60)}m`
  } catch { return "" }
}

export function formatToolInput(session: ClaudeSession): string {
  if (!session.tool_input || !session.tool_name) return ""
  const input = session.tool_input
  switch (session.tool_name) {
    case "Bash":
      return input.command || ""
    case "Edit":
    case "Read":
    case "LS":
      return input.path || ""
    case "Glob":
      return input.pattern || ""
    case "Grep":
      return `${input.pattern || ""} in ${input.path || "."}`
    default:
      return JSON.stringify(input)
  }
}

export function getSessionById(sessionId: string): ClaudeSession | null {
  try {
    const [success, content] = GLib.file_get_contents(`${SESSIONS_DIR}/${sessionId}.json`)
    if (!success) return null
    const text = new TextDecoder().decode(content)
    return normalizeSession(JSON.parse(text))
  } catch { return null }
}
