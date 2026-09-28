
import Hyprland from "gi://AstalHyprland"
import { Widget } from "astal/gtk4"
import AstalApps from "gi://AstalApps?version=0.1"
import GLib from "gi://GLib"
import { agents, agentWorkspaceId } from "../service/Agents"
import { focusWorkspace } from "../service/HyprlandActions"
import AgentPill, { agentMenuOpen } from "./AgentPill"
import Gtk from "gi://Gtk?version=4.0"

type AstalBox = Gtk.Box & { children: Gtk.Widget[] }
type HyprlandInstance = ReturnType<typeof Hyprland.get_default>
type HyprlandWorkspace = ReturnType<HyprlandInstance["get_workspaces"]>[number]
type HyprlandClient = ReturnType<HyprlandInstance["get_clients"]>[number]
type PillEntry = { order: number, pill: Gtk.Widget }

const apps = AstalApps.Apps.new()
const iconByClass = new Map<string, string>()

function disposeWidgetTree(widget: Gtk.Widget): void {
  const children: Gtk.Widget[] = []

  for (
    let child = widget.get_first_child();
    child !== null;
    child = child.get_next_sibling()
  ) {
    children.push(child)
  }

  for (const child of children) disposeWidgetTree(child)

  if (widget.get_parent() !== null) widget.unparent()
  widget.run_dispose()
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
    halign: Gtk.Align.CENTER,
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
      const buttonContentUpdaters = new Map<number, () => void>()
      let updateSource = 0
      let buttonUpdateSource = 0
      const focusedClientAddress = () => {
        try {
          return hypr.get_focused_client()?.get_address() || ""
        } catch {
          return ""
        }
      }
      let lastFocusedClientAddress = focusedClientAddress()

      const updateWorkspaces = () => {
        // Rebuilding disposes the pills, and an open agent menu with them; the
        // menu closing schedules the rebuild instead.
        if (agentMenuOpen.get()) return
        try {
          const oldChildren = [...self.children]
          self.children = []
          for (const child of oldChildren) disposeWidgetTree(child)
          buttonContentUpdaters.clear()

          // Get all workspaces, filter and sort
          const workspaces = hypr.get_workspaces()
          const filtered = workspaces.filter((ws) => !(ws.get_id() >= -99 && ws.get_id() <= -2))
          const sorted = filtered.sort((a, b) => a.get_id() - b.get_id())

          const pillsByWs = new Map<number, PillEntry[]>()
          for (const agent of agents.get()) {
            const wsId = agentWorkspaceId(agent)
            if (wsId === null) continue
            if (!pillsByWs.has(wsId)) pillsByWs.set(wsId, [])
            pillsByWs.get(wsId)!.push({ order: agent.order, pill: AgentPill(agent) })
          }

          self.children = sorted.map((ws) => {
            const id = ws.get_id()
            const focus = () => focusWorkspace(id)

            const button = Widget.Button({
              child: workspaceButtonChild(ws),
              tooltip_text: workspaceTooltip(ws),
              onClicked: focus,
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
            buttonContentUpdaters.set(id, updateButtonContent)

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
              if (buttonContentUpdaters.get(id) === updateButtonContent) {
                buttonContentUpdaters.delete(id)
              }
            })

            const pills = (pillsByWs.get(id) || [])
              .sort((a, b) => a.order - b.order)
              .map(entry => entry.pill)

            const group = Widget.Box({
              css_classes: pills.length > 0
                ? ["workspace-group", "workspace-group-with-pills"]
                : ["workspace-group"],
              children: [button, ...pills],
            })

            const groupGesture = Gtk.GestureClick.new()
            groupGesture.set_button(1)
            groupGesture.connect("released", focus)
            group.add_controller(groupGesture)

            return group
          })
        } catch (error) {
          console.error("❌ Error in updateWorkspaces:", error)
        }
      }

      const scheduleUpdateWorkspaces = () => {
        if (updateSource !== 0) return
        updateSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 80, () => {
          updateSource = 0
          updateWorkspaces()
          return GLib.SOURCE_REMOVE
        })
      }

      const scheduleButtonContentUpdate = () => {
        if (buttonUpdateSource !== 0) return
        buttonUpdateSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 120, () => {
          buttonUpdateSource = 0
          for (const updateButtonContent of buttonContentUpdaters.values()) {
            updateButtonContent()
          }
          return GLib.SOURCE_REMOVE
        })
      }

      // Update initially and when workspaces change
      updateWorkspaces()
      const workspacesId = hypr.connect("notify::workspaces", scheduleUpdateWorkspaces)

      // Listen for workspace/window events that affect pill placement
      const eventId = hypr.connect("event", (_, eventName, args) => {
        if (
          eventName === "openwindow" ||
          eventName === "closewindow" ||
          eventName === "movewindow" ||
          eventName === "movewindowv2"
        ) {
          scheduleUpdateWorkspaces()
        } else if (
          eventName === "activewindow" ||
          eventName === "activewindowv2"
        ) {
          const address = eventName === "activewindowv2"
            ? args.split(",", 1)[0]
            : focusedClientAddress()
          if (address !== lastFocusedClientAddress) {
            lastFocusedClientAddress = address
            scheduleButtonContentUpdate()
          }
        }
      })

      // Re-render when agents change
      const agentsSub = agents.subscribe(scheduleUpdateWorkspaces)
      const agentMenuSub = agentMenuOpen.subscribe(open => {
        if (!open) scheduleUpdateWorkspaces()
      })
      self.connect("destroy", () => {
        if (updateSource !== 0) GLib.source_remove(updateSource)
        if (buttonUpdateSource !== 0) GLib.source_remove(buttonUpdateSource)
        hypr.disconnect(workspacesId)
        hypr.disconnect(eventId)
        agentsSub()
        agentMenuSub()
      })
    }
  })
}
