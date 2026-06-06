
import Hyprland from "gi://AstalHyprland"
import { Widget } from "astal/gtk4"
import AstalApps from "gi://AstalApps?version=0.1"
import { claudeSessions } from "../service/ClaudeStatus"
import { codexSessions } from "../service/CodexStatus"
import {
  AgentKittyPlacement,
  getAgentKittyPlacements,
  kittyPlacementSortKey,
  withKittyPlacement,
} from "../service/KittyTabs"
import { SessionPill as ClaudeSessionPill, findWorkspaceIdForSession as findClaudeWorkspaceId } from "./ClaudeStatus"
import { SessionPill as CodexSessionPill, findWorkspaceIdForSession as findCodexWorkspaceId } from "./CodexStatus"
import Gtk from "gi://Gtk?version=4.0"

type AstalBox = Gtk.Box & { children: Gtk.Widget[] }
type HyprlandInstance = ReturnType<typeof Hyprland.get_default>
type HyprlandWorkspace = ReturnType<HyprlandInstance["get_workspaces"]>[number]
type HyprlandClient = ReturnType<HyprlandInstance["get_clients"]>[number]
type VisibleAgentState = "idle" | "running" | "waiting" | "compacting"
type PillEntry = { updatedAt: number, kittyOrder: number | null, pill: Gtk.Widget }

const apps = AstalApps.Apps.new()
const iconByClass = new Map<string, string>()

function isVisibleAgentState(state: string): state is VisibleAgentState {
  return state === "idle" || state === "running" || state === "waiting" || state === "compacting"
}

function normalizeAppKey(value: string): string {
  return value.toLowerCase().replace(/\.desktop$/, "")
}

function appIconForClass(clientClass: string): string {
  const normalizedClass = normalizeAppKey(clientClass)
  const cached = iconByClass.get(normalizedClass)
  if (cached !== undefined) return cached

  const app = apps.get_list().find((candidate) => {
    const keys = [
      candidate.get_wm_class(),
      candidate.get_entry(),
      candidate.get_executable(),
      candidate.get_name(),
    ]
    return keys.some(key => normalizeAppKey(key || "") === normalizedClass)
  }) || apps.exact_query(clientClass)[0]

  const icon = app?.get_icon_name() || ""
  iconByClass.set(normalizedClass, icon)
  return icon
}

function workspaceClient(ws: HyprlandWorkspace): HyprlandClient | null {
  try {
    return ws.get_last_client() || null
  } catch {
    return null
  }
}

function workspaceButtonChild(ws: HyprlandWorkspace): Gtk.Widget {
  const client = workspaceClient(ws)
  const clientClass = client?.get_class() || ""
  const iconName = clientClass ? appIconForClass(clientClass) : ""

  const children: Gtk.Widget[] = [
    Widget.Label({
      css_classes: ["workspace-id-label"],
      label: String(ws.get_id()),
      xalign: 0.5,
      valign: Gtk.Align.CENTER,
    }),
  ]

  if (iconName) {
    children.push(
      Widget.Image({
        css_classes: ["workspace-app-icon"],
        iconName,
        valign: Gtk.Align.CENTER,
      })
    )
  }

  return Widget.Box({
    css_classes: ["workspace-button-content"],
    spacing: iconName ? 3 : 0,
    valign: Gtk.Align.CENTER,
    children,
  })
}

function workspaceTooltip(ws: HyprlandWorkspace): string {
  const id = ws.get_id()
  const name = ws.get_name()
  const client = workspaceClient(ws)
  const clientClass = client?.get_class() || "empty"
  const title = client?.get_title() || ""
  const label = name === id.toString() ? `${id}` : `${id} ${name}`

  return title ? `${label}\n${clientClass}: ${title}` : `${label}\n${clientClass}`
}

export default function HyprlandStatus() {
  const hypr = Hyprland.get_default()

  return Widget.Box({
    css_classes: ["workspace-widget"],
    setup: (self: AstalBox) => {
      const updateWorkspaces = () => {
        try {
          self.children = []

          // Get all workspaces, filter and sort
          const workspaces = hypr.get_workspaces()
          const filtered = workspaces.filter((ws) => !(ws.get_id() >= -99 && ws.get_id() <= -2))
          const sorted = filtered.sort((a, b) => a.get_id() - b.get_id())

          const pillsByWs = new Map<number, PillEntry[]>()

          const addPill = (
            wsId: number,
            updatedAt: number,
            placement: AgentKittyPlacement | undefined,
            pill: Gtk.Widget,
          ) => {
            if (!pillsByWs.has(wsId)) pillsByWs.set(wsId, [])
            pillsByWs.get(wsId)!.push({
              updatedAt,
              kittyOrder: placement === undefined ? null : kittyPlacementSortKey(placement),
              pill,
            })
          }

          const parseUpdatedAt = (updatedAt: string) => {
            const value = new Date(updatedAt).getTime()
            return Number.isNaN(value) ? 0 : value
          }

          const visibleClaudeSessions = claudeSessions.get().filter(s => isVisibleAgentState(s.state))
          const visibleCodexSessions = codexSessions.get().filter(s => isVisibleAgentState(s.state))
          const kittyPlacements = getAgentKittyPlacements(hypr, [
            ...visibleClaudeSessions,
            ...visibleCodexSessions,
          ])

          for (const s of visibleClaudeSessions) {
            if (!isVisibleAgentState(s.state)) continue
            const wsId = findClaudeWorkspaceId(s)
            if (wsId === null) continue
            const placement = kittyPlacements.get(s.session_id)
            addPill(
              wsId,
              parseUpdatedAt(s.updated_at),
              placement,
              ClaudeSessionPill(withKittyPlacement(s, placement)),
            )
          }

          for (const s of visibleCodexSessions) {
            if (!isVisibleAgentState(s.state)) continue
            const wsId = findCodexWorkspaceId(s)
            if (wsId === null) continue
            const placement = kittyPlacements.get(s.session_id)
            addPill(
              wsId,
              parseUpdatedAt(s.updated_at),
              placement,
              CodexSessionPill(withKittyPlacement(s, placement)),
            )
          }

          self.children = sorted.map((ws) => {
            const id = ws.get_id()
            const focusWorkspace = () => hypr.dispatch("workspace", String(id))

            const button = Widget.Button({
              child: workspaceButtonChild(ws),
              tooltip_text: workspaceTooltip(ws),
              onClicked: focusWorkspace,
            })

            // Update css_classes based on focused workspace
            const updateClass = () => {
              const isFocused = hypr.get_focused_workspace() === ws
              button.css_classes = isFocused ? ["focused"] : []
            }

            // Update visible icon and tooltip when workspace metadata changes
            const updateButtonContent = () => {
              button.child = workspaceButtonChild(ws)
              button.tooltip_text = workspaceTooltip(ws)
            }

            // Set initial state
            updateClass()

            // Connect to focused workspace changes
            const focusId = hypr.connect("notify::focused-workspace", updateClass)

            // Connect to workspace name changes
            const nameId = ws.connect("notify::name", updateButtonContent)

            // Disconnect when button is destroyed
            button.connect("destroy", () => {
              hypr.disconnect(focusId)
              ws.disconnect(nameId)
            })

            const pills = (pillsByWs.get(id) || [])
              .sort((a, b) => {
                if (a.kittyOrder !== null || b.kittyOrder !== null) {
                  if (a.kittyOrder === null) return 1
                  if (b.kittyOrder === null) return -1
                  if (a.kittyOrder !== b.kittyOrder) return a.kittyOrder - b.kittyOrder
                }
                return b.updatedAt - a.updatedAt
              })
              .map(entry => entry.pill)

            const group = Widget.Box({
              css_classes: pills.length > 0
                ? ["workspace-group", "workspace-group-with-pills"]
                : ["workspace-group"],
              children: [button, ...pills],
            })

            const groupGesture = Gtk.GestureClick.new()
            groupGesture.set_button(1)
            groupGesture.connect("released", focusWorkspace)
            group.add_controller(groupGesture)

            return group
          })
        } catch (error) {
          console.error("❌ Error in updateWorkspaces:", error)
        }
      }

      // Update initially and when workspaces change
      updateWorkspaces()
      hypr.connect("notify::workspaces", updateWorkspaces)

      // Listen for workspace/window events that affect pill placement
      hypr.connect("event", (_, eventName) => {
        if (
          eventName === "renameworkspace" ||
          eventName === "activewindow" ||
          eventName === "activewindowv2" ||
          eventName === "windowtitle" ||
          eventName === "windowtitlev2" ||
          eventName === "openwindow" ||
          eventName === "closewindow" ||
          eventName === "movewindow" ||
          eventName === "movewindowv2"
        ) {
          updateWorkspaces()
        }
      })

      // Re-render when agent sessions change
      const claudeSessionsSub = claudeSessions.subscribe(updateWorkspaces)
      const codexSessionsSub = codexSessions.subscribe(updateWorkspaces)
      self.connect("destroy", () => {
        claudeSessionsSub()
        codexSessionsSub()
      })
    }
  })
}
