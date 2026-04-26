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
import Hyprland from "gi://AstalHyprland"

const CLAUDE_ICON_PATH = GLib.get_home_dir() + "/dotfiles/ags/assets/claude.svg"

function getPpid(pid: number): number | null {
  try {
    const [success, content] = GLib.file_get_contents(`/proc/${pid}/status`)
    if (!success) return null
    const text = new TextDecoder().decode(content)
    const match = text.match(/^PPid:\s+(\d+)/m)
    if (!match) return null
    const ppid = parseInt(match[1])
    return isNaN(ppid) || ppid === 0 ? null : ppid
  } catch { return null }
}

function buildClaudeCwdToPidMap(): Map<string, number> {
  const result = new Map<string, number>()
  try {
    const dir = Gio.File.new_for_path("/proc")
    const enumerator = dir.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null)
    let info: Gio.FileInfo | null
    while ((info = enumerator.next_file(null)) !== null) {
      const name = info.get_name()
      if (!/^\d+$/.test(name)) continue
      const pid = parseInt(name)
      try {
        const [ok, content] = GLib.file_get_contents(`/proc/${pid}/comm`)
        if (!ok) continue
        const comm = new TextDecoder().decode(content).trim()
        if (comm !== "claude") continue
        const target = GLib.file_read_link(`/proc/${pid}/cwd`)
        if (target) result.set(target, pid)
      } catch {}
    }
    enumerator.close(null)
  } catch {}
  return result
}

let cwdToPidCache: { map: Map<string, number>, time: number } | null = null

function getClaudePidByCwd(cwd: string): number | null {
  const now = Date.now()
  if (!cwdToPidCache || now - cwdToPidCache.time > 1000) {
    cwdToPidCache = { map: buildClaudeCwdToPidMap(), time: now }
  }
  const map = cwdToPidCache.map
  const direct = map.get(cwd)
  if (direct) return direct
  for (const [k, v] of map) {
    if (cwd.startsWith(k + "/") || k.startsWith(cwd + "/")) return v
  }
  return null
}

export function findWorkspaceIdForSession(session: ClaudeSession): number | null {
  let pid: number | null = session.claude_pid || null
  if (!pid && session.cwd) pid = getClaudePidByCwd(session.cwd)
  if (!pid) return null

  const hypr = Hyprland.get_default()
  const clients = hypr.get_clients()
  let current: number | null = pid
  for (let i = 0; i < 20 && current && current !== 1; i++) {
    const client = clients.find(c => c.pid === current)
    if (client) {
      const ws = client.workspace
      return ws ? ws.id : null
    }
    current = getPpid(current)
  }
  return null
}

function SessionIcon(session: ClaudeSession) {
  const classes = ["claude-session-icon"]
  if (session.state === "running") classes.push("claude-session-icon-pulsing")
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

export function SessionPill(session: ClaudeSession) {
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
    tooltip_text: `${sanitize(session.action)} — ${session.cwd}\nRight-click: details`,
    children: pillChildren,
  })

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
  const orphans = bind(claudeSessions).as(sessions =>
    sessions.filter(s => findWorkspaceIdForSession(s) === null)
  )
  return Widget.Box({
    css_classes: orphans.as(sessions =>
      sessions.length > 0 ? ["claude-status-widget"] : ["claude-status-widget", "claude-status-empty"]
    ),
    visible: orphans.as(sessions => sessions.length > 0),
    tooltip_text: orphans.as(widgetTooltip),
    children: orphans.as(sessions => sessions.map(SessionPill)),
  })
}
