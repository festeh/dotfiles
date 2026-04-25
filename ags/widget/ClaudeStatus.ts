import { Widget } from "astal/gtk4"
import { bind } from "astal"
import { claudeSessions, sessionDisplayName, ClaudeSession } from "../service/ClaudeStatus"
import Gtk from "gi://Gtk?version=4.0"
import GLib from "gi://GLib"

function stateIconName(state: string): string {
  switch (state) {
    case "waiting": return "dialog-warning-symbolic"
    case "idle": return "selection-mode-symbolic"
    case "unknown": return "dialog-question-symbolic"
    default: return "dialog-question-symbolic"
  }
}

// Global persistent spinner animation state
const spinnerAreas: Gtk.DrawingArea[] = []
let spinnerAngle = 0
const TWO_PI = Math.PI * 2
let spinnerTimer: number | null = null

function ensureSpinnerTimer() {
  if (spinnerTimer !== null) return
  spinnerTimer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 40, () => {
    spinnerAngle = (spinnerAngle + 0.2) % TWO_PI
    for (const area of spinnerAreas) {
      if (area.get_mapped()) {
        area.queue_draw()
      }
    }
    return GLib.SOURCE_CONTINUE
  })
}

function registerSpinner(area: Gtk.DrawingArea) {
  ensureSpinnerTimer()
  spinnerAreas.push(area)
  area.connect("destroy", () => {
    const idx = spinnerAreas.indexOf(area)
    if (idx !== -1) {
      spinnerAreas.splice(idx, 1)
    }
  })
}

function RunningSpinner() {
  const area = new Gtk.DrawingArea()
  area.set_size_request(14, 14)
  area.set_draw_func((_, cr, width, height) => {
    const cx = width / 2
    const cy = height / 2
    const radius = Math.min(width, height) / 2 - 2
    const arcLen = Math.PI * 1.3

    // Catppuccin Mocha blue ~ #89b4fa
    cr.setSourceRGBA(0.537, 0.706, 0.98, 1.0)
    cr.setLineWidth(2)
    cr.setLineCap(1) // Cairo.LineCap.ROUND

    cr.arc(cx, cy, radius, spinnerAngle, spinnerAngle + arcLen)
    cr.stroke()
  })
  registerSpinner(area)
  return area
}

function SessionIcon(session: ClaudeSession) {
  if (session.state === "running") {
    return Widget.Box({
      css_classes: ["claude-session-icon"],
      width_request: 14,
      height_request: 14,
      child: RunningSpinner(),
    })
  }
  return Widget.Image({
    css_classes: ["claude-session-icon"],
    icon_name: stateIconName(session.state),
  })
}

function SessionPill(session: ClaudeSession) {
  return Widget.Box({
    css_classes: ["claude-session-pill", `claude-session-${session.state}`],
    tooltip_text: `${session.action} — ${session.cwd}`,
    children: [
      SessionIcon(session),
      Widget.Label({
        css_classes: ["claude-session-name"],
        label: sessionDisplayName(session),
      }),
    ],
  })
}

export default function ClaudeStatus() {
  return Widget.Box({
    css_classes: bind(claudeSessions).as(sessions =>
      sessions.length > 0 ? ["claude-status-widget"] : ["claude-status-widget", "claude-status-empty"]
    ),
    visible: bind(claudeSessions).as(sessions => sessions.length > 0),
    children: bind(claudeSessions).as(sessions =>
      sessions.map(SessionPill)
    ),
  })
}
