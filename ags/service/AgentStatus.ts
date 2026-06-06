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
  kitty_os_window_pid?: number
  kitty_os_window_index?: number
  kitty_tab_id?: number
  kitty_tab_index?: number
  kitty_tab_title?: string
  kitty_window_id?: number
  kitty_window_index?: number
  kitty_window_title?: string
}

export interface AgentStatusConfig {
  provider: "claude" | "codex"
  sessionsDir: string
  pidField: "claude_pid" | "codex_pid"
  defaultName: string
  staleThresholdMs?: number
  liveProcessNames?: string[]
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
const retainedDirectoryMonitors: Gio.FileMonitor[] = []

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

export function agentSessionPid(session: AgentSession): number | null {
  if (typeof session.codex_pid === "number") return session.codex_pid
  if (typeof session.claude_pid === "number") return session.claude_pid
  return null
}

function readText(path: string): string | null {
  try {
    const [ok, content] = GLib.file_get_contents(path)
    if (!ok) return null
    return new TextDecoder().decode(content)
  } catch {
    return null
  }
}

function isNumeric(value: string): boolean {
  return /^\d+$/.test(value)
}

function processMatches(pid: number, processNames: string[]): boolean {
  const comm = readText(`/proc/${pid}/comm`)?.trim().toLowerCase() || ""
  if (processNames.some(name => comm.includes(name))) return true

  const cmdline = readText(`/proc/${pid}/cmdline`) || ""
  const command = cmdline.split("\0").find(Boolean) || ""
  const slash = command.lastIndexOf("/")
  const executable = (slash >= 0 ? command.slice(slash + 1) : command).toLowerCase()

  return processNames.some(name => executable.includes(name))
}

export function readParentPid(pid: number): number | null {
  try {
    const text = readText(`/proc/${pid}/status`)
    if (text === null) return null

    for (const line of text.split("\n")) {
      if (!line.startsWith("PPid:")) continue
      const value = Number.parseInt(line.split(/\s+/)[1], 10)
      return Number.isNaN(value) ? null : value
    }
  } catch {}

  return null
}

export function ancestorPids(pid: number): Set<number> {
  const pids = new Set<number>()
  let current: number | null = pid

  for (let i = 0; i < 25; i++) {
    if (current === null || current <= 1 || pids.has(current)) break
    pids.add(current)
    current = readParentPid(current)
  }

  return pids
}

function liveProcessSessions<T extends AgentSession>(
  config: AgentStatusConfig,
  existing: T[],
  firstSeen: Map<number, string>,
): T[] {
  const processNames = (config.liveProcessNames || []).map(name => name.toLowerCase())
  if (processNames.length === 0) return []

  const existingPids = new Set(existing.map(session => sessionPid(session, config)).filter(Boolean))
  const seenPids = new Set<number>()
  const sessions: T[] = []

  try {
    const proc = Gio.File.new_for_path("/proc")
    const enumerator = proc.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null)
    let info: Gio.FileInfo | null
    while ((info = enumerator.next_file(null)) !== null) {
      const name = info.get_name()
      if (!isNumeric(name)) continue

      const pid = Number.parseInt(name, 10)
      if (existingPids.has(pid) || !processMatches(pid, processNames)) continue

      if (!firstSeen.has(pid)) firstSeen.set(pid, new Date().toISOString())
      seenPids.add(pid)

      const session: AgentSession = {
        session_id: `${config.provider}-process-${pid}`,
        state: "idle",
        action: "opened",
        cwd: "",
        transcript: "",
        updated_at: firstSeen.get(pid)!,
        tool_count: 0,
        source: "process",
      }
      session[config.pidField] = pid
      sessions.push(session as T)
    }
    enumerator.close(null)
  } catch {
    return []
  }

  for (const pid of firstSeen.keys()) {
    if (!seenPids.has(pid) && !existingPids.has(pid)) firstSeen.delete(pid)
  }

  return sessions
}

function readSessions<T extends AgentSession>(
  config: AgentStatusConfig,
  liveProcessFirstSeen: Map<number, string>,
): T[] {
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

  const fileSessions = sessions
    .filter(s => !isStale(s, thresholdMs))

  return [...fileSessions, ...liveProcessSessions(config, fileSessions, liveProcessFirstSeen)]
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
  const liveProcessFirstSeen = new Map<number, string>()
  let refreshSource = 0
  let staleRefreshSource = 0

  function refreshSessions(): void {
    const fresh = readSessions<T>(config, liveProcessFirstSeen)
    scheduleStaleRefresh(fresh)
    if (!sameSessions(sessions.get(), fresh)) {
      sessions.set(fresh)
    }
  }

  function scheduleRefresh(delayMs = 50): void {
    if (refreshSource !== 0) return
    refreshSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, delayMs, () => {
      refreshSource = 0
      refreshSessions()
      return GLib.SOURCE_REMOVE
    })
  }

  function scheduleStaleRefresh(currentSessions: T[]): void {
    if (staleRefreshSource !== 0) {
      GLib.source_remove(staleRefreshSource)
      staleRefreshSource = 0
    }

    const thresholdMs = config.staleThresholdMs ?? DEFAULT_STALE_THRESHOLD_MS
    const now = Date.now()
    let nextDelay: number | null = null

    for (const session of currentSessions) {
      if (session.state === "idle") continue
      const updated = new Date(session.updated_at).getTime()
      if (Number.isNaN(updated)) continue
      const delay = Math.max(1000, updated + thresholdMs - now + 100)
      nextDelay = nextDelay === null ? delay : Math.min(nextDelay, delay)
    }

    if (nextDelay !== null) {
      staleRefreshSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, nextDelay, () => {
        staleRefreshSource = 0
        refreshSessions()
        return GLib.SOURCE_REMOVE
      })
    }
  }

  function isSessionWritePath(path: string | null): boolean {
    if (path === null) return false
    return path.endsWith(".json") || /\.json\.\d+\.tmp$/.test(path)
  }

  GLib.mkdir_with_parents(config.sessionsDir, 0o755)

  const dirFile = Gio.File.new_for_path(config.sessionsDir)
  const monitor = dirFile.monitor_directory(Gio.FileMonitorFlags.NONE, null)
  retainedDirectoryMonitors.push(monitor)
  monitor.set_rate_limit(50)
  monitor.connect("changed", (_m, file, other, _event) => {
    if (isSessionWritePath(file.get_path()) || isSessionWritePath(other?.get_path() ?? null)) {
      scheduleRefresh()
    }
  })

  const hypr = Hyprland.get_default()
  hypr.connect("client-added", () => scheduleRefresh())
  hypr.connect("client-removed", () => scheduleRefresh())

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
