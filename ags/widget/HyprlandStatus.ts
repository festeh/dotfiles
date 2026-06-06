
import Hyprland from "gi://AstalHyprland"
import { Widget } from "astal/gtk4"
import { claudeSessions } from "../service/ClaudeStatus"
import { codexSessions } from "../service/CodexStatus"
import { SessionPill as ClaudeSessionPill, findWorkspaceIdForSession as findClaudeWorkspaceId } from "./ClaudeStatus"
import { SessionPill as CodexSessionPill, findWorkspaceIdForSession as findCodexWorkspaceId } from "./CodexStatus"
import Gtk from "gi://Gtk?version=4.0"

type AstalBox = Gtk.Box & { children: Gtk.Widget[] }

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

          const pillsByWs = new Map<number, { updatedAt: number, pill: Gtk.Widget }[]>()

          const addPill = (wsId: number, updatedAt: number, pill: Gtk.Widget) => {
            if (!pillsByWs.has(wsId)) pillsByWs.set(wsId, [])
            pillsByWs.get(wsId)!.push({ updatedAt, pill })
          }

          const parseUpdatedAt = (updatedAt: string) => {
            const value = new Date(updatedAt).getTime()
            return Number.isNaN(value) ? 0 : value
          }

          for (const s of claudeSessions.get()) {
            const wsId = findClaudeWorkspaceId(s)
            if (wsId === null) continue
            addPill(wsId, parseUpdatedAt(s.updated_at), ClaudeSessionPill(s))
          }

          for (const s of codexSessions.get()) {
            const wsId = findCodexWorkspaceId(s)
            if (wsId === null) continue
            addPill(wsId, parseUpdatedAt(s.updated_at), CodexSessionPill(s))
          }

          self.children = sorted.map((ws) => {
            const id = ws.get_id()
            const focusWorkspace = () => hypr.dispatch("workspace", String(id))
            const getLabel = () => {
              const name = ws.get_name()
              return name === id.toString() ? name : `<span alpha="50%">${id}</span> ${name}`
            }

            const button = Widget.Button({
              child: Widget.Label({
                label: getLabel(),
                use_markup: true,
              }),
              onClicked: focusWorkspace,
            })

            // Update css_classes based on focused workspace
            const updateClass = () => {
              const isFocused = hypr.get_focused_workspace() === ws
              button.css_classes = isFocused ? ["focused"] : []
            }

            // Update label when workspace name changes
            const updateLabel = () => {
              const label = button.child as ReturnType<typeof Widget.Label>
              label.label = getLabel()
            }

            // Set initial state
            updateClass()

            // Connect to focused workspace changes
            const focusId = hypr.connect("notify::focused-workspace", updateClass)

            // Connect to workspace name changes
            const nameId = ws.connect("notify::name", updateLabel)

            // Disconnect when button is destroyed
            button.connect("destroy", () => {
              hypr.disconnect(focusId)
              ws.disconnect(nameId)
            })

            const pills = (pillsByWs.get(id) || [])
              .sort((a, b) => b.updatedAt - a.updatedAt)
              .map(entry => entry.pill)

            const group = Widget.Box({
              css_classes: ["workspace-group"],
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
