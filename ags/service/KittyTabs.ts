import GLib from "gi://GLib"
import Hyprland from "gi://AstalHyprland"
import {
  AgentSession,
  agentSessionPid,
  ancestorPids,
} from "./AgentStatus"

type HyprlandInstance = ReturnType<typeof Hyprland.get_default>
type HyprlandClient = ReturnType<HyprlandInstance["get_clients"]>[number]

interface KittyWindow {
  id?: number
  pid?: number
  title?: string
}

interface KittyTab {
  id?: number
  title?: string
  windows?: KittyWindow[]
}

interface KittyOsWindow {
  tabs?: KittyTab[]
}

export interface AgentKittyPlacement {
  osWindowPid: number
  osWindowIndex: number
  tabId: number
  tabIndex: number
  tabTitle?: string
  windowId: number
  windowIndex: number
  windowTitle?: string
  verifiedAt: number
}

interface CachedAgentKittyPlacement extends AgentKittyPlacement {
  sessionPid: number
  seenAt: number
}

interface MissedAgentKittyPlacement {
  sessionPid: number
  checkedAt: number
  seenAt: number
}

const KITTY_CORRECTION_INTERVAL_MS = 60000
const KITTY_CACHE_RETENTION_MS = 3600000
const placementCache = new Map<string, CachedAgentKittyPlacement>()
const missCache = new Map<string, MissedAgentKittyPlacement>()

function clientClass(client: HyprlandClient): string {
  try {
    return client.get_class().toLowerCase()
  } catch {
    return ""
  }
}

function isKittyClient(client: HyprlandClient): boolean {
  return clientClass(client) === "kitty"
}

function readKittyLayout(kittyPid: number): KittyOsWindow[] | null {
  try {
    const address = GLib.shell_quote(`unix:@kitty-${kittyPid}`)
    const [success, stdout] = GLib.spawn_command_line_sync(`timeout 1s kitty @ --to ${address} ls`)
    if (!success || stdout === null) return null

    const layout = JSON.parse(new TextDecoder().decode(stdout))
    return Array.isArray(layout) ? layout : null
  } catch {
    return null
  }
}

function findPlacementInLayout(
  layout: KittyOsWindow[],
  osWindowPid: number,
  osWindowIndex: number,
  sessionAncestors: Set<number>,
  verifiedAt: number,
): AgentKittyPlacement | null {
  for (const osWindow of layout) {
    const tabs = osWindow.tabs || []
    for (let tabIndex = 0; tabIndex < tabs.length; tabIndex++) {
      const tab = tabs[tabIndex]
      if (typeof tab.id !== "number") continue

      const windows = tab.windows || []
      for (let windowIndex = 0; windowIndex < windows.length; windowIndex++) {
        const window = windows[windowIndex]
        if (typeof window.id !== "number" || typeof window.pid !== "number") continue
        if (!sessionAncestors.has(window.pid)) continue

        return {
          osWindowPid,
          osWindowIndex,
          tabId: tab.id,
          tabIndex,
          tabTitle: typeof tab.title === "string" ? tab.title : undefined,
          windowId: window.id,
          windowIndex,
          windowTitle: typeof window.title === "string" ? window.title : undefined,
          verifiedAt,
        }
      }
    }
  }

  return null
}

function refreshKittyPlacements(hypr: HyprlandInstance, sessions: AgentSession[], now: number): void {
  const sessionAncestors = new Map<string, { pid: number, ancestors: Set<number> }>()
  for (const session of sessions) {
    const pid = agentSessionPid(session)
    if (pid !== null) sessionAncestors.set(session.session_id, { pid, ancestors: ancestorPids(pid) })
  }

  if (sessionAncestors.size === 0) return

  const matchedSessionIds = new Set<string>()
  const kittyClients = hypr.get_clients().filter(isKittyClient)
  kittyClients.forEach((client, clientIndex) => {
    const kittyPid = client.get_pid()
    const layout = readKittyLayout(kittyPid)
    if (layout === null) return

    for (const session of sessions) {
      if (matchedSessionIds.has(session.session_id)) continue
      const process = sessionAncestors.get(session.session_id)
      if (process === undefined) continue

      const placement = findPlacementInLayout(layout, kittyPid, clientIndex, process.ancestors, now)
      if (placement === null) continue

      matchedSessionIds.add(session.session_id)
      missCache.delete(session.session_id)
      placementCache.set(session.session_id, {
        ...placement,
        sessionPid: process.pid,
        seenAt: now,
      })
    }
  })

  for (const session of sessions) {
    if (matchedSessionIds.has(session.session_id)) continue

    const process = sessionAncestors.get(session.session_id)
    if (process === undefined) continue

    const cached = placementCache.get(session.session_id)
    if (cached !== undefined && cached.sessionPid === process.pid) {
      placementCache.set(session.session_id, {
        ...cached,
        verifiedAt: now,
        seenAt: now,
      })
      continue
    }

    missCache.set(session.session_id, {
      sessionPid: process.pid,
      checkedAt: now,
      seenAt: now,
    })
  }

  for (const [sessionId, cached] of placementCache) {
    if (now - cached.seenAt > KITTY_CACHE_RETENTION_MS) placementCache.delete(sessionId)
  }
  for (const [sessionId, missed] of missCache) {
    if (now - missed.seenAt > KITTY_CACHE_RETENTION_MS) missCache.delete(sessionId)
  }
}

function needsKittyRefresh(session: AgentSession, now: number): boolean {
  const pid = agentSessionPid(session)
  if (pid === null) return false

  const cached = placementCache.get(session.session_id)
  const missed = missCache.get(session.session_id)
  if (missed !== undefined && missed.sessionPid === pid) {
    return now - missed.checkedAt > KITTY_CORRECTION_INTERVAL_MS
  }

  if (cached === undefined) return true
  if (cached.sessionPid !== pid) return true

  return now - cached.verifiedAt > KITTY_CORRECTION_INTERVAL_MS
}

export function getAgentKittyPlacements(
  hypr: HyprlandInstance,
  sessions: AgentSession[],
): Map<string, AgentKittyPlacement> {
  const now = Date.now()
  if (sessions.some(session => needsKittyRefresh(session, now))) {
    refreshKittyPlacements(hypr, sessions, now)
  }

  const placements = new Map<string, AgentKittyPlacement>()
  for (const session of sessions) {
    const cached = placementCache.get(session.session_id)
    if (cached !== undefined) placements.set(session.session_id, cached)
  }

  return placements
}

export function withKittyPlacement<T extends AgentSession>(
  session: T,
  placement: AgentKittyPlacement | undefined,
): T {
  if (placement === undefined) return session

  return {
    ...session,
    kitty_os_window_pid: placement.osWindowPid,
    kitty_os_window_index: placement.osWindowIndex,
    kitty_tab_id: placement.tabId,
    kitty_tab_index: placement.tabIndex,
    kitty_tab_title: placement.tabTitle,
    kitty_window_id: placement.windowId,
    kitty_window_index: placement.windowIndex,
    kitty_window_title: placement.windowTitle,
  }
}

export function kittyPlacementSortKey(placement: AgentKittyPlacement): number {
  return placement.osWindowIndex * 1000000 + placement.tabIndex * 1000 + placement.windowIndex
}

export function focusSessionKittyTab(session: AgentSession): void {
  if (
    typeof session.kitty_os_window_pid !== "number" ||
    typeof session.kitty_tab_id !== "number"
  ) {
    return
  }

  const address = GLib.shell_quote(`unix:@kitty-${session.kitty_os_window_pid}`)

  try {
    if (typeof session.kitty_window_id === "number") {
      GLib.spawn_command_line_async(
        `kitty @ --to ${address} focus-window --match id:${session.kitty_window_id} --no-response`,
      )
      return
    }

    GLib.spawn_command_line_async(
      `kitty @ --to ${address} focus-tab --match id:${session.kitty_tab_id} --no-response`,
    )
  } catch {}
}
