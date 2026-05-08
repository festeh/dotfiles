import { Widget } from "astal/gtk4"
import { bind } from "astal"
import Gtk from "gi://Gtk?version=4.0"
import Hyprland from "gi://AstalHyprland"
import {
  AgentSession,
  AgentStatusService,
} from "../service/AgentStatus"

export interface AgentWidgetConfig<T extends AgentSession> {
  provider: "claude" | "codex"
  iconPath: string
  classPrefix: string
  title: string
  service: AgentStatusService<T>
}

export function findWorkspaceIdForAgentSession(session: AgentSession): number | null {
  if (!session.window_address) return null
  const client = Hyprland.get_default().get_client(session.window_address)
  return client?.workspace?.id ?? null
}

function prefixed(config: AgentWidgetConfig<any>, suffix: string): string[] {
  return [`agent-${suffix}`, `${config.classPrefix}-${suffix}`]
}

function SessionIcon<T extends AgentSession>(session: T, config: AgentWidgetConfig<T>) {
  const classes = prefixed(config, "session-icon")
  if (session.state === "running" || session.state === "compacting") {
    classes.push("agent-session-icon-pulsing", `${config.classPrefix}-session-icon-pulsing`)
  }
  const image = Widget.Image({
    css_classes: classes,
    file: config.iconPath,
  })
  image.set_pixel_size(14)
  return image
}

function sanitize(str: string | undefined, max?: number): string {
  const cleaned = (str || "").replace(/\n/g, " ")
  if (max !== undefined && cleaned.length > max) {
    return cleaned.slice(0, max) + "..."
  }
  return cleaned
}

function getPillLabel<T extends AgentSession>(session: T, config: AgentWidgetConfig<T>): string {
  if (session.state === "running" || session.state === "waiting" || session.state === "compacting") {
    return sanitize(session.action || config.service.sessionDisplayName(session), 20)
  }
  return sanitize(config.service.sessionDisplayName(session), 20)
}

function formatIdleElapsed(session: AgentSession): string {
  try {
    const updated = new Date(session.updated_at).getTime()
    const e = Math.floor((Date.now() - updated) / 1000)
    let s: string
    if (e < 60) s = `${e}s`
    else if (e < 3600) s = `${Math.floor(e / 60)}m`
    else s = `${Math.floor(e / 3600)}h`
    return `${s} idle`
  } catch { return "idle" }
}

function DetailSection(
  config: AgentWidgetConfig<any>,
  label: string,
  value: string,
  valueClass?: string,
) {
  return Widget.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 2,
    css_classes: prefixed(config, "detail-section"),
    children: [
      Widget.Label({
        css_classes: prefixed(config, "detail-label"),
        label,
        halign: Gtk.Align.START,
      }),
      Widget.Label({
        css_classes: valueClass
          ? [...prefixed(config, "detail-value"), valueClass]
          : prefixed(config, "detail-value"),
        label: value,
        wrap: true,
        max_width_chars: 48,
        halign: Gtk.Align.START,
      }),
    ],
  })
}

function DetailPopover<T extends AgentSession>(
  session: T,
  parent: Gtk.Widget,
  config: AgentWidgetConfig<T>,
): Gtk.Popover {
  const popover = new Gtk.Popover()
  popover.set_parent(parent)

  const children: Gtk.Widget[] = []
  const stateDot = "● "

  children.push(
    Widget.Box({
      spacing: 8,
      css_classes: prefixed(config, "detail-header"),
      children: [
        Widget.Label({
          css_classes: [
            `agent-detail-state-${session.state}`,
            `${config.classPrefix}-detail-state-${session.state}`,
          ],
          label: `${stateDot}${session.state.toUpperCase()}`,
        }),
        Widget.Label({
          css_classes: prefixed(config, "detail-project"),
          label: config.service.sessionDisplayName(session),
        }),
      ],
    })
  )

  if (session.prompt) {
    children.push(DetailSection(config, "Prompt", sanitize(session.prompt)))
  }

  if (session.tool_name) {
    const toolHeader = session.tool_count > 0
      ? `Tool: ${session.tool_name} (#${session.tool_count})`
      : `Tool: ${session.tool_name}`

    const toolDetail = sanitize(config.service.formatToolInput(session))

    children.push(
      Widget.Box({
        orientation: Gtk.Orientation.VERTICAL,
        spacing: 2,
        css_classes: prefixed(config, "detail-section"),
        children: [
          Widget.Label({
            css_classes: prefixed(config, "detail-label"),
            label: toolHeader,
            halign: Gtk.Align.START,
          }),
          ...(toolDetail
            ? [
                Widget.Label({
                  css_classes: [...prefixed(config, "detail-value"), "agent-detail-monospace", `${config.classPrefix}-detail-monospace`],
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

  if (session.approval_reason) {
    children.push(DetailSection(config, "Approval", sanitize(session.approval_reason)))
  }

  if (session.model) {
    children.push(DetailSection(config, "Model", sanitize(session.model)))
  }

  if (session.agent_type) {
    children.push(DetailSection(config, "Subagent", sanitize(session.agent_type)))
  }

  if (session.error) {
    children.push(DetailSection(config, "Error", sanitize(session.error), "agent-detail-error"))
  }

  if (session.notification_message) {
    children.push(DetailSection(config, "Notification", sanitize(session.notification_message)))
  }

  if (session.last_assistant_message && session.state === "idle") {
    children.push(
      DetailSection(
        config,
        "Last response",
        sanitize(session.last_assistant_message, 200)
      )
    )
  }

  children.push(
    Widget.Box({
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 4,
      css_classes: prefixed(config, "detail-footer"),
      children: [
        Widget.Label({
          css_classes: prefixed(config, "detail-meta"),
          label: session.cwd,
          wrap: true,
          max_width_chars: 48,
          halign: Gtk.Align.START,
        }),
        Widget.Label({
          css_classes: prefixed(config, "detail-meta"),
          label: `Updated ${config.service.formatElapsed(session)} ago`,
          halign: Gtk.Align.START,
        }),
      ],
    })
  )

  const content = Widget.Box({
    css_classes: prefixed(config, "detail-popover"),
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 10,
    children,
  })

  popover.set_child(content)
  return popover
}

export function AgentSessionPill<T extends AgentSession>(
  session: T,
  config: AgentWidgetConfig<T>,
) {
  const labelWidget = session.state === "idle"
    ? Widget.Label({
        css_classes: prefixed(config, "session-name"),
        label: bind(config.service.idleTick).as(() => formatIdleElapsed(session)),
        width_chars: 7,
        xalign: 0,
      })
    : Widget.Label({
        css_classes: prefixed(config, "session-name"),
        label: getPillLabel(session, config),
      })

  const pillChildren: Gtk.Widget[] = [SessionIcon(session, config), labelWidget]

  if (session.tool_count > 0) {
    pillChildren.push(
      Widget.Label({
        css_classes: prefixed(config, "session-badge"),
        label: `${session.tool_count}`,
      })
    )
  }

  const pill = Widget.Box({
    css_classes: [
      "agent-session-pill",
      `${config.classPrefix}-session-pill`,
      `agent-session-${session.state}`,
      `${config.classPrefix}-session-${session.state}`,
    ],
    tooltip_text: `${sanitize(session.action)} - ${session.cwd}\nClick: focus workspace - Right-click: details`,
    children: pillChildren,
  })

  const leftGesture = Gtk.GestureClick.new()
  leftGesture.set_button(1)
  leftGesture.connect("released", () => {
    const fresh = config.service.getSessionById(session.session_id) || session
    const wsId = findWorkspaceIdForAgentSession(fresh)
    if (wsId === null) return
    const hypr = Hyprland.get_default()
    const ws = hypr.get_workspaces().find(w => w.get_id() === wsId)
    if (ws) ws.focus()
    else hypr.dispatch("workspace", String(wsId))
  })
  pill.add_controller(leftGesture)

  const rightGesture = Gtk.GestureClick.new()
  rightGesture.set_button(3)
  rightGesture.connect("pressed", () => {
    const fresh = config.service.getSessionById(session.session_id)
    if (!fresh) return
    const popover = DetailPopover(fresh, pill, config)
    popover.popup()
  })
  pill.add_controller(rightGesture)

  return pill
}
