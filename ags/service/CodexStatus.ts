import GLib from "gi://GLib"
import {
  AgentSession,
  createAgentStatusService,
} from "./AgentStatus"

export interface CodexSession extends AgentSession {
  codex_pid?: number
}

const codexStatus = createAgentStatusService<CodexSession>({
  provider: "codex",
  sessionsDir: GLib.get_home_dir() + "/.cache/ags-codex/sessions",
  pidField: "codex_pid",
  defaultName: "codex",
  staleThresholdMs: 300000,
  liveProcessNames: ["codex"],
})

export const codexSessions = codexStatus.sessions
export const idleTick = codexStatus.idleTick
export const sessionDisplayName = codexStatus.sessionDisplayName
export const formatElapsed = codexStatus.formatElapsed
export const formatToolInput = codexStatus.formatToolInput
export const getSessionById = codexStatus.getSessionById
export const refreshSessions = codexStatus.refreshSessions
