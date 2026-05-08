import { Variable } from "astal"
import GLib from "gi://GLib"
import Gio from "gi://Gio"
import Hyprland from "gi://AstalHyprland"

export type AgentState = "idle" | "running" | "waiting" | "compacting" | "unknown"

export interface AgentSession {
  session_id: string
  state: AgentState
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
  model?: string
  turn_id?: string
  source?: string
  approval_reason?: string
  window_address?: string
  claude_pid?: number
  codex_pid?: number
}

export interface AgentStatusConfig {
  provider: "claude" | "codex"
  sessionsDir: string
  pidField: "claude_pid" | "codex_pid"
  defaultName: string
  staleThresholdMs?: number
}

export interface AgentStatusService<T extends AgentSession> {
  sessions: Variable<T[]>
  idleTick: Variable<number>
  sessionDisplayName: (session: T) => string
  formatElapsed: (session: T) => string
  formatToolInput: (session: T) => string
  getSessionById: (sessionId: string) => T | null
  refreshSessions: () => void
}

const DEFAULT_STALE_THRESHOLD_MS = 300000

function basename(path: string, fallback: string): string {
  if (!path) return fallback
  const idx = path.lastIndexOf("/")
  return idx >= 0 ? path.slice(idx + 1) || path : path
}

function isStale(session: AgentSession, thresholdMs: number): boolean {
  if (session.state === "idle") return false
  try {
    const updated = new Date(session.updated_at).getTime()
    return Date.now() - updated > thresholdMs
  } catch { return true }
}

function normalizeSession(raw: any, config: AgentStatusConfig): AgentSession {
  const session: AgentSession = {
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
    model: raw.model || undefined,
    turn_id: raw.turn_id || undefined,
    source: raw.source || undefined,
    approval_reason: raw.approval_reason || undefined,
    window_address: typeof raw.window_address === "string" ? raw.window_address : undefined,
  }

  const pid = raw[config.pidField]
  if (typeof pid === "number") session[config.pidField] = pid

  return session
}

function sessionPid(session: AgentSession, config: AgentStatusConfig): number | undefined {
  const pid = session[config.pidField]
  return typeof pid === "number" ? pid : undefined
}

function readSessions<T extends AgentSession>(config: AgentStatusConfig): T[] {
  if (!GLib.file_test(config.sessionsDir, GLib.FileTest.IS_DIR)) return []
  const thresholdMs = config.staleThresholdMs ?? DEFAULT_STALE_THRESHOLD_MS
  const sessions: T[] = []

  try {
    const dir = Gio.File.new_for_path(config.sessionsDir)
    const enumerator = dir.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null)
    let info: Gio.FileInfo | null
    while ((info = enumerator.next_file(null)) !== null) {
      const name = info.get_name()
      if (!name.endsWith(".json")) continue
      const path = `${config.sessionsDir}/${name}`

      try {
        const [ok, content] = GLib.file_get_contents(path)
        if (!ok) continue
        const text = new TextDecoder().decode(content)
        const session = normalizeSession(JSON.parse(text), config)
        const pid = sessionPid(session, config)

        // Hyprland recycles addresses, so PID liveness is the authoritative
        // cleanup signal for sessions that died without writing a final event.
        if (pid && !GLib.file_test(`/proc/${pid}`, GLib.FileTest.IS_DIR)) {
          try { Gio.File.new_for_path(path).delete(null) } catch {}
          continue
        }

        sessions.push(session as T)
      } catch {}
    }
    enumerator.close(null)
  } catch { return [] }

  return sessions
    .filter(s => !isStale(s, thresholdMs))
    .sort((a, b) => new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime())
}

function sameSessions<T extends AgentSession>(a: T[], b: T[]): boolean {
  if (a.length !== b.length) return false
  for (let i = 0; i < a.length; i++) {
    if (JSON.stringify(a[i]) !== JSON.stringify(b[i])) return false
  }
  return true
}

export const idleTick = Variable<number>(0)
GLib.timeout_add(GLib.PRIORITY_DEFAULT, 5000, () => {
  idleTick.set(idleTick.get() + 1)
  return GLib.SOURCE_CONTINUE
})

export function createAgentStatusService<T extends AgentSession = AgentSession>(
  config: AgentStatusConfig,
): AgentStatusService<T> {
  const sessions = Variable<T[]>([])

  function refreshSessions(): void {
    const fresh = readSessions<T>(config)
    if (!sameSessions(sessions.get(), fresh)) {
      sessions.set(fresh)
    }
  }

  GLib.mkdir_with_parents(config.sessionsDir, 0o755)

  const dirFile = Gio.File.new_for_path(config.sessionsDir)
  const monitor = dirFile.monitor_directory(Gio.FileMonitorFlags.NONE, null)
  monitor.set_rate_limit(50)
  monitor.connect("changed", (_m, file, _other, _event) => {
    const path = file.get_path()
    if (path && path.endsWith(".json")) refreshSessions()
  })

  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
    refreshSessions()
    return GLib.SOURCE_CONTINUE
  })

  Hyprland.get_default().connect("client-removed", () => refreshSessions())

  refreshSessions()

  function sessionDisplayName(session: T): string {
    return basename(session.cwd, config.defaultName)
  }

  function formatElapsed(session: T): string {
    try {
      const updated = new Date(session.updated_at).getTime()
      const elapsed = Math.floor((Date.now() - updated) / 1000)
      if (elapsed < 60) return `${elapsed}s`
      if (elapsed < 3600) return `${Math.floor(elapsed / 60)}m`
      return `${Math.floor(elapsed / 3600)}h ${Math.floor((elapsed % 3600) / 60)}m`
    } catch { return "" }
  }

  function formatToolInput(session: T): string {
    if (!session.tool_input || !session.tool_name) return ""
    const input = session.tool_input
    switch (session.tool_name) {
      case "Bash":
      case "apply_patch":
        return input.command || input.patch || ""
      case "Edit":
      case "Write":
      case "Read":
      case "LS":
        return input.path || input.file_path || ""
      case "Glob":
        return input.pattern || ""
      case "Grep":
        return `${input.pattern || ""} in ${input.path || "."}`
      default:
        return JSON.stringify(input)
    }
  }

  function getSessionById(sessionId: string): T | null {
    try {
      const [success, content] = GLib.file_get_contents(`${config.sessionsDir}/${sessionId}.json`)
      if (!success) return null
      const text = new TextDecoder().decode(content)
      return normalizeSession(JSON.parse(text), config) as T
    } catch { return null }
  }

  return {
    sessions,
    idleTick,
    sessionDisplayName,
    formatElapsed,
    formatToolInput,
    getSessionById,
    refreshSessions,
  }
}
