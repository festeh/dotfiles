import { Widget } from "astal/gtk4"
import { bind } from "astal"
import Gtk from "gi://Gtk?version=4.0"
import Hyprland from "gi://AstalHyprland"
import GLib from "gi://GLib"
import {
  AgentSession,
  AgentStatusService,
  agentSessionPid,
  ancestorPids,
} from "../service/AgentStatus"
import { focusSessionKittyTab } from "../service/KittyTabs"

export interface AgentWidgetConfig<T extends AgentSession> {
  provider: "claude" | "codex"
  iconPath: string
  classPrefix: string
  title: string
  service: AgentStatusService<T>
}

export function findWorkspaceIdForAgentSession(session: AgentSession): number | null {
  const hypr = Hyprland.get_default()

  if (session.window_address) {
    const client = hypr.get_client(session.window_address)
    const workspaceId = client?.get_workspace()?.get_id() ?? client?.workspace?.id ?? null
    if (workspaceId !== null) return workspaceId
  }

  const pid = agentSessionPid(session)
  if (pid === null) return null

  return findWorkspaceIdByPid(hypr, pid)
}

function findWorkspaceIdByPid(hypr: ReturnType<typeof Hyprland.get_default>, pid: number): number | null {
  const pids = ancestorPids(pid)
  const client = hypr.get_clients().find((client) => pids.has(client.get_pid()))
  return client?.get_workspace()?.get_id() ?? null
}

function prefixed(config: AgentWidgetConfig<any>, suffix: string): string[] {
  return [`agent-${suffix}`, `${config.classPrefix}-${suffix}`]
}

function SessionIcon<T extends AgentSession>(session: T, config: AgentWidgetConfig<T>) {
  const classes = prefixed(config, "session-icon")
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

function basename(path: string): string {
  if (!path) return ""
  const trimmed = path.replace(/\/+$/, "")
  const slash = trimmed.lastIndexOf("/")
  return slash >= 0 ? trimmed.slice(slash + 1) || trimmed : trimmed
}

function normalizeIdentityLabel(value: string | undefined): string {
  return (value || "")
    .replace(/\n/g, " ")
    .replace(/\s+/g, " ")
    .replace(/^[^\p{L}\p{N}~./_-]+/u, "")
    .trim()
}

function isUsefulIdentityLabel(label: string, session: AgentSession, config: AgentWidgetConfig<any>): boolean {
  if (!label) return false

  const lower = label.toLowerCase()
  const cwdName = config.service.sessionDisplayName(session).toLowerCase()
  const homeName = basename(GLib.get_home_dir()).toLowerCase()

  if (lower === cwdName || lower === homeName || lower === "~") return false
  if (lower === "bash" || lower === "zsh" || lower === "fish") return false
  if (lower === "thinking" || lower === "thinking..." || lower === "finished") return false
  if (lower === "needs input" || lower === "idle" || lower === "running") return false

  return true
}

function sessionIdentityLabel<T extends AgentSession>(session: T, config: AgentWidgetConfig<T>): string {
  const candidates = [
    session.kitty_tab_title,
    session.kitty_window_title,
    session.prompt,
  ]

  for (const candidate of candidates) {
    const label = normalizeIdentityLabel(candidate)
    if (isUsefulIdentityLabel(label, session, config)) return label
  }

  return config.service.sessionDisplayName(session)
}

function getPillLabel<T extends AgentSession>(session: T, config: AgentWidgetConfig<T>): string {
  const label = sessionIdentityLabel(session, config)
  if (session.state === "waiting") return `input: ${sanitize(label, 14)}`
  if (session.state === "compacting") return `compact: ${sanitize(label, 12)}`
  return sanitize(label, 20)
}

function formatIdleElapsed(session: AgentSession): string {
  try {
    const updated = new Date(session.updated_at).getTime()
    const e = Math.floor((Date.now() - updated) / 1000)
    if (e < 60) return `${e}s`
    if (e < 3600) return `${Math.floor(e / 60)}m`
    return `${Math.floor(e / 3600)}h`
  } catch { return "idle" }
}

function getIdlePillLabel<T extends AgentSession>(session: T, config: AgentWidgetConfig<T>): string {
  return `${sanitize(sessionIdentityLabel(session, config), 15)} ${formatIdleElapsed(session)}`
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
          label: sessionIdentityLabel(session, config),
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
        label: bind(config.service.idleTick).as(() => getIdlePillLabel(session, config)),
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

  const pillClasses = [
    "agent-session-pill",
    `${config.classPrefix}-session-pill`,
    `agent-session-${session.state}`,
    `${config.classPrefix}-session-${session.state}`,
  ]

  const pill = Widget.Box({
    css_classes: pillClasses,
    tooltip_text: `${sanitize(session.action)} - ${session.cwd}\nClick: focus workspace - Right-click: details`,
    children: pillChildren,
  })

  const leftGesture = Gtk.GestureClick.new()
  leftGesture.set_button(1)
  leftGesture.connect("released", () => {
    const diskSession = config.service.getSessionById(session.session_id)
    const fresh = diskSession ? { ...session, ...diskSession } : session
    const wsId = findWorkspaceIdForAgentSession(fresh)
    if (wsId === null) return
    const hypr = Hyprland.get_default()
    const ws = hypr.get_workspaces().find(w => w.get_id() === wsId)
    if (ws) ws.focus()
    else hypr.dispatch("workspace", String(wsId))

    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
      focusSessionKittyTab(fresh)
      return GLib.SOURCE_REMOVE
    })
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
