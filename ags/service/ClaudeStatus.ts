import { Variable } from "astal"
import GLib from "gi://GLib"

const SESSIONS_FILE = GLib.get_home_dir() + "/.cache/ags-claude/sessions.json"
const STALE_THRESHOLD_MS = 60000 // 60 seconds

export interface ClaudeSession {
  session_id: string
  state: "idle" | "running" | "waiting" | "unknown"
  action: string
  cwd: string
  transcript: string
  updated_at: string
}

function basename(path: string): string {
  if (!path) return "claude"
  const idx = path.lastIndexOf("/")
  return idx >= 0 ? path.slice(idx + 1) || path : path
}

function isStale(session: ClaudeSession): boolean {
  if (session.state === "idle") {
    return false
  }
  try {
    const updated = new Date(session.updated_at).getTime()
    return Date.now() - updated > STALE_THRESHOLD_MS
  } catch {
    return true
  }
}

function readSessions(): ClaudeSession[] {
  try {
    const [success, content] = GLib.file_get_contents(SESSIONS_FILE)
    if (!success) return []
    const text = new TextDecoder().decode(content)
    const data = JSON.parse(text)
    const sessions: ClaudeSession[] = Object.values(data.sessions || {})
    return sessions
      .filter(s => !isStale(s))
      .sort((a, b) => new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime())
  } catch (e) {
    return []
  }
}

function sessionKey(s: ClaudeSession): string {
  // Ignore action churn so running pills don't flash on every tool change
  return `${s.session_id}|${s.state}|${s.cwd}`
}

function sessionsEqual(a: ClaudeSession[], b: ClaudeSession[]): boolean {
  if (a.length !== b.length) return false
  for (let i = 0; i < a.length; i++) {
    if (sessionKey(a[i]) !== sessionKey(b[i])) return false
  }
  return true
}

export const claudeSessions = Variable<ClaudeSession[]>([])

// Poll every 1 second but only update Variable when meaningful fields change
// (ignoring updated_at / transcript churn so CSS animations don't re-fire)
GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
  const next = readSessions()
  if (!sessionsEqual(claudeSessions.get(), next)) {
    claudeSessions.set(next)
  }
  return GLib.SOURCE_CONTINUE
})

// Initial read
claudeSessions.set(readSessions())

export function sessionDisplayName(session: ClaudeSession): string {
  return basename(session.cwd)
}
