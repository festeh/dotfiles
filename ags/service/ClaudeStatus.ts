import GLib from "gi://GLib"
import {
  AgentSession,
  createAgentStatusService,
} from "./AgentStatus"

export interface ClaudeSession extends AgentSession {
  claude_pid?: number
}

const claudeStatus = createAgentStatusService<ClaudeSession>({
  provider: "claude",
  sessionsDir: GLib.get_home_dir() + "/.cache/ags-claude/sessions",
  pidField: "claude_pid",
  defaultName: "claude",
  staleThresholdMs: 300000,
})

export const claudeSessions = claudeStatus.sessions
export const idleTick = claudeStatus.idleTick
export const sessionDisplayName = claudeStatus.sessionDisplayName
export const formatElapsed = claudeStatus.formatElapsed
export const formatToolInput = claudeStatus.formatToolInput
export const getSessionById = claudeStatus.getSessionById
export const refreshSessions = claudeStatus.refreshSessions
