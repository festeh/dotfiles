import { Widget } from "astal/gtk4"
import { bind } from "astal"
import {
  claudeSessions,
  sessionDisplayName,
  formatElapsed,
  formatToolInput,
  getSessionById,
  ClaudeSession,
} from "../service/ClaudeStatus"
import Gtk from "gi://Gtk?version=4.0"
import Gio from "gi://Gio"
import GLib from "gi://GLib"

let spinnerAngle = 0
const spinnerAreas: Set<Gtk.DrawingArea> = new Set()
let spinnerSource: number | null = null

function startSpinnerTimer() {
  if (spinnerSource !== null) return
  spinnerSource = setInterval(() => {
    spinnerAngle = (spinnerAngle + 0.15) % (2 * Math.PI)
    for (const area of spinnerAreas) {
      area.queue_draw()
    }
  }, 50)
}

function SessionIcon(session: ClaudeSession) {
  if (session.state === "running") {
    const area = new Gtk.DrawingArea()
    area.set_size_request(14, 14)
    area.set_draw_func((widget, cr, width, height) => {
      const color = widget.get_color()
      cr.setSourceRGBA(color.red, color.green, color.blue, color.alpha)
      const cx = width / 2
      const cy = height / 2
      const radius = Math.min(cx, cy) - 2
      cr.setLineWidth(2)
      cr.arc(cx, cy, radius, spinnerAngle, spinnerAngle + 1.2 * Math.PI)
      cr.stroke()
    }, null)
    spinnerAreas.add(area)
    startSpinnerTimer()
    return area
  }
  const names: Record<string, string> = {
    idle: "selection-mode-symbolic",
    waiting: "dialog-warning-symbolic",
    unknown: "dialog-question-symbolic",
  }
  return Widget.Image({
    css_classes: ["claude-session-icon"],
    icon_name: names[session.state] || "dialog-question-symbolic",
  })
}

function sanitize(str: string, max?: number): string {
  const cleaned = str.replace(/\n/g, " ")
  if (max !== undefined && cleaned.length > max) {
    return cleaned.slice(0, max) + "..."
  }
  return cleaned
}

function getPillLabel(session: ClaudeSession): string {
  if (session.state === "running" || session.state === "waiting") {
    return sanitize(session.action || sessionDisplayName(session), 20)
  }
  return sanitize(sessionDisplayName(session), 20)
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

function SessionPill(session: ClaudeSession) {
  const pillChildren: Gtk.Widget[] = [
    SessionIcon(session),
    Widget.Label({
      css_classes: ["claude-session-name"],
      label: getPillLabel(session),
    }),
  ]

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
    tooltip_text: `${sanitize(session.action)} — ${session.cwd}\nLeft-click: focus window  Right-click: details`,
    children: pillChildren,
  })

  // Left click: focus the corresponding claude window
  const leftGesture = Gtk.GestureClick.new()
  leftGesture.set_button(1)
  leftGesture.connect("pressed", () => {
    try {
      Gio.Subprocess.new(
        [
          "python3",
          GLib.get_home_dir() + "/dotfiles/scripts/focus-claude.py",
          String(session.claude_pid || ""),
          session.cwd,
        ],
        Gio.SubprocessFlags.NONE,
      )
    } catch {
      // silently ignore spawn failures
    }
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

function widgetTooltip(sessions: ClaudeSession[]): string {
  if (sessions.length === 0) return ""
  return sessions
    .map(s => `• ${sessionDisplayName(s)}: ${s.cwd} (${s.state})`)
    .join("\n")
}

export default function ClaudeStatus() {
  return Widget.Box({
    css_classes: bind(claudeSessions).as(sessions =>
      sessions.length > 0 ? ["claude-status-widget"] : ["claude-status-widget", "claude-status-empty"]
    ),
    visible: bind(claudeSessions).as(sessions => sessions.length > 0),
    tooltip_text: bind(claudeSessions).as(widgetTooltip),
    children: bind(claudeSessions).as(sessions =>
      sessions.map(SessionPill)
    ),
  })
}
