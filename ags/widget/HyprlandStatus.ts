
import Hyprland from "gi://AstalHyprland"
import { Widget } from "astal/gtk4"
import { bind } from "astal"


export default function HyprlandStatus() {
  const hypr = Hyprland.get_default()

  return Widget.Box({
    css_classes: ["workspace-widget"],
    setup: (self) => {
      const updateWorkspaces = () => {
        try {
          console.log("🔄 updateWorkspaces called")

          // Clear all children (GTK will handle cleanup)
          console.log(`🗑️  Clearing ${self.children.length} existing workspace buttons`)
          self.children = []

          // Get all workspaces, filter and sort
          const workspaces = hypr.get_workspaces()
          console.log(`📋 Raw workspaces: ${workspaces.length}`)

          const filtered = workspaces.filter((ws) => !(ws.get_id() >= -99 && ws.get_id() <= -2))
          console.log(`🔍 After filter: ${filtered.length}`)

          const sorted = filtered.sort((a, b) => a.get_id() - b.get_id())

          const workspaceIds = sorted.map(ws => ws.get_id()).join(", ")
          console.log(`✨ Creating buttons for ${sorted.length} workspaces: [${workspaceIds}]`)

          // Add workspace buttons
          self.children = sorted.map((ws) => {
          const getLabel = () => {
            const id = ws.get_id()
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

          return button
        })
        } catch (error) {
          console.error("❌ Error in updateWorkspaces:", error)
        }
      }

      // Update initially and when workspaces change
      updateWorkspaces()
      hypr.connect("notify::workspaces", updateWorkspaces)

      // Listen for workspace rename events only
      // (create/destroy handled by notify::workspaces above)
      hypr.connect("event", (_, eventName, args) => {
        console.log(`Hyprland event: ${eventName} ${args}`)
        if (eventName === "renameworkspace") {
          // Rebuild all workspace buttons with updated names
          updateWorkspaces()
        }
      })
    }
  })
}
