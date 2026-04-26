
import Hyprland from "gi://AstalHyprland"
import { Widget } from "astal/gtk4"
import { claudeSessions, ClaudeSession } from "../service/ClaudeStatus"
import { SessionPill, findWorkspaceIdForSession } from "./ClaudeStatus"


export default function HyprlandStatus() {
  const hypr = Hyprland.get_default()

  return Widget.Box({
    css_classes: ["workspace-widget"],
    setup: (self) => {
      const updateWorkspaces = () => {
        try {
          self.children = []

          // Get all workspaces, filter and sort
          const workspaces = hypr.get_workspaces()
          const filtered = workspaces.filter((ws) => !(ws.get_id() >= -99 && ws.get_id() <= -2))
          const sorted = filtered.sort((a, b) => a.get_id() - b.get_id())

          // Group claude sessions by workspace id
          const sessionsByWs = new Map<number, ClaudeSession[]>()
          for (const s of claudeSessions.get()) {
            const wsId = findWorkspaceIdForSession(s)
            if (wsId === null) continue
            if (!sessionsByWs.has(wsId)) sessionsByWs.set(wsId, [])
            sessionsByWs.get(wsId)!.push(s)
          }

          self.children = sorted.map((ws) => {
          const id = ws.get_id()
          const getLabel = () => {
            const name = ws.get_name()
            return name === id.toString() ? name : `<span alpha="50%">${id}</span> ${name}`
          }

          const button = Widget.Button({
            child: Widget.Label({
              label: getLabel(),
              use_markup: true,
            }),
            onClicked: () => ws.focus(),
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

          const pills = (sessionsByWs.get(id) || []).map(SessionPill)

          return Widget.Box({
            css_classes: ["workspace-group"],
            children: [button, ...pills],
          })
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

      // Re-render when claude sessions change
      const sessionsSub = claudeSessions.subscribe(updateWorkspaces)
      self.connect("destroy", () => sessionsSub())
    }
  })
}
