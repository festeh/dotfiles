import GLib from "gi://GLib"
import {
  AgentSessionPill,
  findWorkspaceIdForAgentSession,
} from "./AgentStatus"
import {
  CodexSession,
  codexSessions,
  formatElapsed,
  formatToolInput,
  getSessionById,
  idleTick,
  refreshSessions,
  sessionDisplayName,
} from "../service/CodexStatus"

const CODEX_ICON_PATH = GLib.get_home_dir() + "/dotfiles/ags/assets/codex.svg"

const codexWidgetConfig = {
  provider: "codex" as const,
  iconPath: CODEX_ICON_PATH,
  classPrefix: "codex",
  title: "Codex",
  service: {
    sessions: codexSessions,
    idleTick,
    sessionDisplayName,
    formatElapsed,
    formatToolInput,
    getSessionById,
    refreshSessions,
  },
}

export function findWorkspaceIdForSession(session: CodexSession): number | null {
  return findWorkspaceIdForAgentSession(session)
}

export function SessionPill(session: CodexSession) {
  return AgentSessionPill(session, codexWidgetConfig)
}
