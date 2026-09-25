import { Widget } from "astal/gtk4"
import { bind } from "astal"
import Gtk from "gi://Gtk?version=4.0"
import GLib from "gi://GLib"
import {
  Agent,
  AgentHookState,
  agentClock,
  agentIcon,
  agents,
  focusAgent,
} from "../service/Agents"

const TICKET_RE = /\b[A-Z][A-Z0-9]+-\d+\b/
const GENERIC_LABELS = new Set([
  "~", "main", "master", "bash", "zsh", "fish",
  "claude code", "codex", "kimi",
  "thinking", "thinking...", "finished", "needs input", "idle", "running",
])

function oneLine(value: string | undefined, max?: number): string {
  const cleaned = (value || "").replace(/\s+/g, " ").trim()
  return max !== undefined && cleaned.length > max ? cleaned.slice(0, max) + "..." : cleaned
}

function basename(path: string): string {
  const trimmed = path.replace(/\/+$/, "")
  return trimmed.slice(trimmed.lastIndexOf("/") + 1)
}

function normalizeLabel(value: string | undefined): string {
  return oneLine(value).replace(/^[^\p{L}\p{N}~./_-]+/u, "")
}

function identityLabel(agent: Agent): string {
  const cwdName = basename(agent.cwd) || agent.id

  const branch = normalizeLabel(agent.hook?.git_branch)
  if (branch) {
    const ticket = branch.match(TICKET_RE)
    if (ticket) return ticket[0]
    return branch === "main" || branch === "master" ? cwdName : branch
  }

  const sources = [agent.tabTitle, agent.title, agent.hook?.prompt].map(normalizeLabel)
  for (const source of sources) {
    const ticket = source.match(TICKET_RE)
    if (ticket) return ticket[0]
  }

  const ignored = new Set([...GENERIC_LABELS, cwdName.toLowerCase(), basename(GLib.get_home_dir()).toLowerCase()])
  return sources.find(source => source && !ignored.has(source.toLowerCase())) || cwdName
}

function pillLabel(agent: Agent): string {
  const label = identityLabel(agent)
  if (agent.state === "waiting") return `input: ${oneLine(label, 14)}`
  if (agent.state === "compacting") return `compact: ${oneLine(label, 12)}`
  return oneLine(label, agent.state === "idle" ? 15 : 20)
}

function formatElapsed(since: number): string {
  const seconds = Math.max(0, Math.floor((Date.now() - since) / 1000))
  if (seconds < 60) return `${seconds}s`
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
  return `${Math.floor(seconds / 86400)}d`
}

function toolLine(hook: AgentHookState | null): string {
  if (!hook?.tool_name) return ""
  return hook.tool_detail ? `${hook.tool_name}: ${hook.tool_detail}` : hook.tool_name
}

function Badge(agent: Agent): Gtk.Widget | null {
  if ((agent.state === "idle" || agent.state === "waiting") && agent.since > 0) {
    const since = agent.since
    return Widget.Label({
      css_classes: ["agent-session-badge"],
      label: bind(agentClock).as(() => formatElapsed(since)),
    })
  }
  if (agent.hook?.tool_count) {
    return Widget.Label({ css_classes: ["agent-session-badge"], label: `${agent.hook.tool_count}` })
  }
  return null
}

function DetailSection(label: string, value: string, valueClasses: string[] = []): Gtk.Widget {
  return Widget.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 2,
    css_classes: ["agent-detail-section"],
    children: [
      Widget.Label({ css_classes: ["agent-detail-label"], label, halign: Gtk.Align.START }),
      Widget.Label({
        css_classes: ["agent-detail-value", ...valueClasses],
        label: value,
        wrap: true,
        max_width_chars: 48,
        halign: Gtk.Align.START,
      }),
    ],
  })
}

function DetailPopover(agent: Agent, hook: AgentHookState, parent: Gtk.Widget): Gtk.Popover {
  const children: Gtk.Widget[] = [
    Widget.Box({
      spacing: 8,
      css_classes: ["agent-detail-header"],
      children: [
        Widget.Label({ css_classes: [`agent-detail-state-${agent.state}`], label: `● ${agent.state.toUpperCase()}` }),
        Widget.Label({ css_classes: ["agent-detail-project"], label: identityLabel(agent) }),
      ],
    }),
  ]

  if (hook.prompt) children.push(DetailSection("Prompt", oneLine(hook.prompt)))
  if (hook.tool_name) {
    const count = hook.tool_count ? ` (#${hook.tool_count})` : ""
    children.push(DetailSection(`Tool: ${hook.tool_name}${count}`, hook.tool_detail || "", ["agent-detail-monospace"]))
  }
  if (hook.approval_reason) children.push(DetailSection("Approval", oneLine(hook.approval_reason)))
  if (hook.model) children.push(DetailSection("Model", hook.model))
  if (hook.agent_type) children.push(DetailSection("Subagent", hook.agent_type))
  if (hook.error) children.push(DetailSection("Error", oneLine(hook.error), ["agent-detail-error"]))
  if (hook.notification_message) children.push(DetailSection("Notification", oneLine(hook.notification_message)))
  if (hook.last_assistant_message && agent.state === "idle") {
    children.push(DetailSection("Last response", oneLine(hook.last_assistant_message, 200)))
  }

  const updatedAt = Date.parse(hook.updated_at)
  children.push(Widget.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 4,
    css_classes: ["agent-detail-footer"],
    children: [
      Widget.Label({ css_classes: ["agent-detail-meta"], label: agent.cwd, wrap: true, max_width_chars: 48, halign: Gtk.Align.START }),
      ...(Number.isNaN(updatedAt) ? [] : [
        Widget.Label({ css_classes: ["agent-detail-meta"], label: `Updated ${formatElapsed(updatedAt)} ago`, halign: Gtk.Align.START }),
      ]),
    ],
  }))

  const popover = new Gtk.Popover()
  popover.set_parent(parent)
  popover.set_child(Widget.Box({
    css_classes: ["agent-detail-popover"],
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 10,
    children,
  }))
  popover.connect("closed", () => {
    GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
      if (popover.get_parent() !== null) popover.unparent()
      return GLib.SOURCE_REMOVE
    })
  })
  return popover
}

export default function AgentPill(agent: Agent): Gtk.Widget {
  const icon = Widget.Image({ css_classes: ["agent-session-icon"], file: agentIcon(agent.id) })
  icon.set_pixel_size(14)

  const badge = Badge(agent)
  const tooltip = [
    agent.title,
    oneLine(toolLine(agent.hook), 120),
    agent.cwd,
    agent.hook ? "Click: focus - Right-click: details" : "Click: focus",
  ].filter(Boolean).join("\n")

  const pill = Widget.Box({
    css_classes: ["agent-session-pill", `agent-session-${agent.state}`, `agent-${agent.id}`],
    tooltip_text: tooltip,
    children: [
      icon,
      Widget.Label({ css_classes: ["agent-session-name"], label: pillLabel(agent) }),
      ...(badge ? [badge] : []),
    ],
  })

  const leftClick = Gtk.GestureClick.new()
  leftClick.set_button(1)
  leftClick.connect("released", () => focusAgent(agent))
  pill.add_controller(leftClick)

  const rightClick = Gtk.GestureClick.new()
  rightClick.set_button(3)
  rightClick.connect("pressed", () => {
    const fresh = agents.get().find(candidate => candidate.key === agent.key) ?? agent
    if (fresh.hook) DetailPopover(fresh, fresh.hook, pill).popup()
  })
  pill.add_controller(rightClick)

  return pill
}
