import GLib from "gi://GLib"
import {
  AgentSession,
  createAgentStatusService,
} from "./AgentStatus"

export interface KimiSession extends AgentSession {
  kimi_pid?: number
}

// No liveProcessNames: Kimi Code hooks cover the full session lifecycle
// (SessionStart/SessionEnd), so we skip the per-refresh /proc scan that
// Codex needs to discover hook-less processes.
const kimiStatus = createAgentStatusService<KimiSession>({
  provider: "kimi",
  sessionsDir: GLib.get_home_dir() + "/.cache/ags-kimi/sessions",
  pidField: "kimi_pid",
  defaultName: "kimi",
  staleThresholdMs: 300000,
})

export const kimiSessions = kimiStatus.sessions
export const idleTick = kimiStatus.idleTick
export const sessionDisplayName = kimiStatus.sessionDisplayName
export const formatElapsed = kimiStatus.formatElapsed
export const formatToolInput = kimiStatus.formatToolInput
export const getSessionById = kimiStatus.getSessionById
export const refreshSessions = kimiStatus.refreshSessions
