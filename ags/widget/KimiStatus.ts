import GLib from "gi://GLib"
import {
  AgentSessionPill,
  findWorkspaceIdForAgentSession,
} from "./AgentStatus"
import {
  KimiSession,
  kimiSessions,
  formatElapsed,
  formatToolInput,
  getSessionById,
  idleTick,
  refreshSessions,
  sessionDisplayName,
} from "../service/KimiStatus"

const KIMI_ICON_PATH = GLib.get_home_dir() + "/dotfiles/ags/assets/kimi.svg"

const kimiWidgetConfig = {
  provider: "kimi" as const,
  iconPath: KIMI_ICON_PATH,
  classPrefix: "kimi",
  title: "Kimi",
  service: {
    sessions: kimiSessions,
    idleTick,
    sessionDisplayName,
    formatElapsed,
    formatToolInput,
    getSessionById,
    refreshSessions,
  },
}

export function findWorkspaceIdForSession(session: KimiSession): number | null {
  return findWorkspaceIdForAgentSession(session)
}

export function SessionPill(session: KimiSession) {
  return AgentSessionPill(session, kimiWidgetConfig)
}
