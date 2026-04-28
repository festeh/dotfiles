import { Widget } from "astal/gtk4"
import { bind } from "astal"
import {
  sessionDisplayName,
  formatElapsed,
  formatToolInput,
  getSessionById,
  idleTick,
  ClaudeSession,
} from "../service/ClaudeStatus"
import Gtk from "gi://Gtk?version=4.0"
import GLib from "gi://GLib"
import Hyprland from "gi://AstalHyprland"

const CLAUDE_ICON_PATH = GLib.get_home_dir() + "/dotfiles/ags/assets/claude.svg"

export function findWorkspaceIdForSession(session: ClaudeSession): number | null {
  if (!session.window_address) return null
  const client = Hyprland.get_default().get_client(session.window_address)
  return client?.workspace?.id ?? null
}

function SessionIcon(session: ClaudeSession) {
  const classes = ["claude-session-icon"]
  if (session.state === "running" || session.state === "compacting") classes.push("claude-session-icon-pulsing")
  const image = Widget.Image({
    css_classes: classes,
    file: CLAUDE_ICON_PATH,
  })
  image.set_pixel_size(14)
  return image
}

function sanitize(str: string, max?: number): string {
  const cleaned = str.replace(/\n/g, " ")
  if (max !== undefined && cleaned.length > max) {
    return cleaned.slice(0, max) + "..."
  }
  return cleaned
}

function getPillLabel(session: ClaudeSession): string {
  if (session.state === "running" || session.state === "waiting" || session.state === "compacting") {
    return sanitize(session.action || sessionDisplayName(session), 20)
  }
  return sanitize(sessionDisplayName(session), 20)
}

function formatIdleElapsed(session: ClaudeSession): string {
  // Fixed-width "<XXXX> idle" so pills don't jitter as the timer ticks.
  try {
    const updated = new Date(session.updated_at).getTime()
    const e = Math.floor((Date.now() - updated) / 1000)
    let s: string
    if (e < 60) s = `${e}s`
    else if (e < 3600) s = `${Math.floor(e / 60)}m`
    else s = `${Math.floor(e / 3600)}h`
    return `${s.padStart(4, " ")} idle`
  } catch { return "     idle" }
}

function DetailSection(label: string, value: string, valueClass?: string) {
  return Widget.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 2,
    css_classes: ["claude-detail-section"],
    children: [
      Widget.Label({
        css_classes: ["claude-detail-label"],
        label,
        halign: Gtk.Align.START,
      }),
      Widget.Label({
        css_classes: valueClass ? ["claude-detail-value", valueClass] : ["claude-detail-value"],
        label: value,
        wrap: true,
        max_width_chars: 48,
        halign: Gtk.Align.START,
      }),
    ],
  })
}

function DetailPopover(session: ClaudeSession, parent: Gtk.Widget): Gtk.Popover {
  const popover = new Gtk.Popover()
  popover.set_parent(parent)

  const children: Gtk.Widget[] = []

  // Header: state dot + project name
  const stateColors: Record<string, string> = {
    running: "● ",
    waiting: "● ",
    idle: "● ",
    compacting: "● ",
    unknown: "● ",
  }

  children.push(
    Widget.Box({
      spacing: 8,
      css_classes: ["claude-detail-header"],
      children: [
        Widget.Label({
          css_classes: [`claude-detail-state-${session.state}`],
          label: `${stateColors[session.state] || "● "}${session.state.toUpperCase()}`,
        }),
        Widget.Label({
          css_classes: ["claude-detail-project"],
          label: sessionDisplayName(session),
        }),
      ],
    })
  )

  // Prompt
  if (session.prompt) {
    children.push(DetailSection("Prompt", sanitize(session.prompt)))
  }

  // Tool info
  if (session.tool_name) {
    const toolHeader = session.tool_count > 0
      ? `Tool: ${session.tool_name} (#${session.tool_count})`
      : `Tool: ${session.tool_name}`

    const toolDetail = sanitize(formatToolInput(session))

    children.push(
      Widget.Box({
        orientation: Gtk.Orientation.VERTICAL,
        spacing: 2,
        css_classes: ["claude-detail-section"],
        children: [
          Widget.Label({
            css_classes: ["claude-detail-label"],
            label: toolHeader,
            halign: Gtk.Align.START,
          }),
          ...(toolDetail
            ? [
                Widget.Label({
                  css_classes: ["claude-detail-value", "claude-detail-monospace"],
                  label: toolDetail,
                  wrap: true,
                  max_width_chars: 48,
                  halign: Gtk.Align.START,
                }),
              ]
            : []),
        ],
      })
    )
  }

  // Subagent
  if (session.agent_type) {
    children.push(DetailSection("Subagent", sanitize(session.agent_type)))
  }

  // Error
  if (session.error) {
    children.push(DetailSection("Error", sanitize(session.error), "claude-detail-error"))
  }

  // Notification
  if (session.notification_message) {
    children.push(DetailSection("Notification", sanitize(session.notification_message)))
  }

  // Last assistant message (for idle sessions)
  if (session.last_assistant_message && session.state === "idle") {
    children.push(
      DetailSection(
        "Last response",
        sanitize(session.last_assistant_message, 200)
      )
    )
  }

  // Footer metadata
  children.push(
    Widget.Box({
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 4,
      css_classes: ["claude-detail-footer"],
      children: [
        Widget.Label({
          css_classes: ["claude-detail-meta"],
          label: session.cwd,
          wrap: true,
          max_width_chars: 48,
          halign: Gtk.Align.START,
        }),
        Widget.Label({
          css_classes: ["claude-detail-meta"],
          label: `Updated ${formatElapsed(session)} ago`,
          halign: Gtk.Align.START,
        }),
      ],
    })
  )

  const content = Widget.Box({
    css_classes: ["claude-detail-popover"],
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 10,
    children,
  })

  popover.set_child(content)
  return popover
}

export function SessionPill(session: ClaudeSession) {
  const labelWidget = session.state === "idle"
    ? Widget.Label({
        css_classes: ["claude-session-name"],
        label: bind(idleTick).as(() => formatIdleElapsed(session)),
      })
    : Widget.Label({
        css_classes: ["claude-session-name"],
        label: getPillLabel(session),
      })

  const pillChildren: Gtk.Widget[] = [SessionIcon(session), labelWidget]

  // Tool count badge
  if (session.tool_count > 0) {
    pillChildren.push(
      Widget.Label({
        css_classes: ["claude-session-badge"],
        label: `${session.tool_count}`,
      })
    )
  }

  const pill = Widget.Box({
    css_classes: ["claude-session-pill", `claude-session-${session.state}`],
    tooltip_text: `${sanitize(session.action)} — ${session.cwd}\nClick: focus workspace · Right-click: details`,
    children: pillChildren,
  })

  // Left click: focus the session's hyprland workspace
  const leftGesture = Gtk.GestureClick.new()
  leftGesture.set_button(1)
  leftGesture.connect("released", () => {
    const fresh = getSessionById(session.session_id) || session
    const wsId = findWorkspaceIdForSession(fresh)
    if (wsId === null) return
    const hypr = Hyprland.get_default()
    const ws = hypr.get_workspaces().find(w => w.get_id() === wsId)
    if (ws) ws.focus()
    else hypr.dispatch("workspace", String(wsId))
  })
  pill.add_controller(leftGesture)

  // Right click: show detail popover
  const rightGesture = Gtk.GestureClick.new()
  rightGesture.set_button(3)
  rightGesture.connect("pressed", () => {
    const fresh = getSessionById(session.session_id)
    if (!fresh) return
    const popover = DetailPopover(fresh, pill)
    popover.popup()
  })
  pill.add_controller(rightGesture)

  return pill
}

