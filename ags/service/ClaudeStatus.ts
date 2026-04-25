import { Variable } from "astal"
import GLib from "gi://GLib"

const SESSIONS_FILE = GLib.get_home_dir() + "/.cache/ags-claude/sessions.json"
const STALE_THRESHOLD_MS = 60000

export interface ClaudeSession {
  session_id: string
  state: "idle" | "running" | "waiting" | "unknown"
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
  }
}

function readSessions(): ClaudeSession[] {
  try {
    const [success, content] = GLib.file_get_contents(SESSIONS_FILE)
    if (!success) return []
    const text = new TextDecoder().decode(content)
    const data = JSON.parse(text)
    const sessions: ClaudeSession[] = Object.values(data.sessions || {}).map(normalizeSession)
    return sessions
      .filter(s => !isStale(s))
      .sort((a, b) => new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime())
  } catch { return [] }
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
  }
  return true
}

export const claudeSessions = Variable<ClaudeSession[]>([])

GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
  const fresh = readSessions()
  if (!sameSessions(claudeSessions.get(), fresh)) {
    claudeSessions.set(fresh)
  }
  return GLib.SOURCE_CONTINUE
})

claudeSessions.set(readSessions())

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
    const [success, content] = GLib.file_get_contents(SESSIONS_FILE)
    if (!success) return null
    const text = new TextDecoder().decode(content)
    const data = JSON.parse(text)
    const raw = data.sessions?.[sessionId]
    if (!raw) return null
    return normalizeSession(raw)
  } catch { return null }
}
