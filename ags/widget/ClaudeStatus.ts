import GLib from "gi://GLib"
import {
  AgentSessionPill,
  findWorkspaceIdForAgentSession,
} from "./AgentStatus"
import {
  ClaudeSession,
  claudeSessions,
  formatElapsed,
  formatToolInput,
  getSessionById,
  idleTick,
  refreshSessions,
  sessionDisplayName,
} from "../service/ClaudeStatus"

const CLAUDE_ICON_PATH = GLib.get_home_dir() + "/dotfiles/ags/assets/claude.svg"

const claudeWidgetConfig = {
  provider: "claude" as const,
  iconPath: CLAUDE_ICON_PATH,
  classPrefix: "claude",
  title: "Claude",
  service: {
    sessions: claudeSessions,
    idleTick,
    sessionDisplayName,
    formatElapsed,
    formatToolInput,
    getSessionById,
    refreshSessions,
  },
}

export function findWorkspaceIdForSession(session: ClaudeSession): number | null {
  return findWorkspaceIdForAgentSession(session)
}

export function SessionPill(session: ClaudeSession) {
  return AgentSessionPill(session, claudeWidgetConfig)
}
