
import Hyprland from "gi://AstalHyprland"
import { Widget } from "astal/gtk4"
import { bind } from "astal"


export default function HyprlandStatus() {
  const hypr = Hyprland.get_default()

  return Widget.Box({
    css_classes: ["workspace-widget"],
    setup: (self) => {
      const updateWorkspaces = () => {
        // Remove all children
        self.children.forEach((child) => child.destroy())

        // Get all workspaces, filter and sort
        const workspaces = hypr.get_workspaces()
          .filter((ws) => !(ws.get_id() >= -99 && ws.get_id() <= -2))
          .sort((a, b) => a.get_id() - b.get_id())

        // Add workspace buttons
        self.children = workspaces.map((ws) => {
          const button = Widget.Button({
            label: ws.get_name(),
            onClicked: () => ws.focus(),
          })

          // Update className based on focused workspace
          const updateClass = () => {
            const isFocused = hypr.get_focused_workspace() === ws
            button.className = isFocused ? "focused" : ""
          }

          // Update label when workspace name changes
          const updateLabel = () => {
            button.label = ws.get_name()
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

          return button
        })
      }

      // Update initially and when workspaces change
      updateWorkspaces()
      hypr.connect("notify::workspaces", updateWorkspaces)
    }
  })
}
