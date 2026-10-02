import { Widget } from "astal/gtk4"
import { Variable, bind } from "astal"
import Gtk from "gi://Gtk?version=4.0"
import GLib from "gi://GLib"
import Pango from "gi://Pango"
import {
  Agent,
  AgentHookState,
  AgentState,
  BackgroundTask,
  agentClock,
  agentIcon,
  agents,
  dismissAgent,
  focusAgent,
  markAgentIdle,
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
  if (agent.toolCount !== null) {
    return Widget.Label({ css_classes: ["agent-session-badge"], label: `${agent.toolCount}` })
  }
  return null
}

const TASK_KINDS: [BackgroundTask["kind"], string][] = [["process", "ps"], ["agent", "ag"]]

/** One "N ps" / "N ag" segment per kind of background task running; none when idle. */
function TaskBadges(hook: AgentHookState | null): Gtk.Widget[] {
  const tasks = hook?.background_tasks ?? []
  return TASK_KINDS.flatMap(([kind, suffix]) => {
    const count = tasks.filter(task => task.kind === kind).length
    return count > 0 ? [Widget.Label({ css_classes: ["agent-session-badge"], label: `${count} ${suffix}` })] : []
  })
}

const STATE_NAMES: Record<AgentState, string> = {
  idle: "Idle",
  running: "Running",
  waiting: "Needs input",
  compacting: "Compacting",
}

let openMenus = 0
/** True while an agent menu is open; the bar holds off rebuilding pills meanwhile. */
export const agentMenuOpen = Variable(false)

function tildePath(path: string): string {
  const home = GLib.get_home_dir()
  return path === home || path.startsWith(home + "/") ? "~" + path.slice(home.length) : path
}

/** Last responses are Markdown; emphasis and code markers are noise in a label. */
function plainText(value: string): string {
  return value.replace(/\*\*|__|`/g, "")
}

function replaceChildren(box: Gtk.Box, children: Gtk.Widget[]): void {
  for (let child = box.get_first_child(); child !== null; child = box.get_first_child()) box.remove(child)
  for (const child of children) box.append(child)
}

function Text(value: string, lines: number, classes: string[] = []): Gtk.Widget {
  return Widget.Label({
    css_classes: ["agent-menu-text", ...classes],
    label: value,
    wrap: true,
    wrap_mode: Pango.WrapMode.WORD_CHAR,
    lines,
    ellipsize: Pango.EllipsizeMode.END,
    max_width_chars: 50,
    xalign: 0,
  })
}

function Section(caption: string, content: Gtk.Widget, classes: string[] = []): Gtk.Widget {
  return Widget.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 4,
    css_classes: ["agent-menu-section", ...classes],
    children: [
      Widget.Label({ css_classes: ["agent-menu-caption"], label: caption, xalign: 0 }),
      content,
    ],
  })
}

function ToolBlock(hook: AgentHookState): Gtk.Widget {
  return Widget.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 3,
    css_classes: ["agent-menu-code"],
    children: [
      Widget.Label({ css_classes: ["agent-menu-code-name"], label: hook.tool_name, xalign: 0 }),
      ...(hook.tool_detail ? [Text(hook.tool_detail, 3, ["agent-menu-code-text"])] : []),
    ],
  })
}

function MenuHeader(agent: Agent): Gtk.Widget[] {
  const icon = Widget.Image({ file: agentIcon(agent.id) })
  icon.set_pixel_size(18)

  const title = identityLabel(agent)
  const branch = normalizeLabel(agent.hook?.git_branch)
  const subtitle = [branch !== title ? branch : "", tildePath(agent.cwd)].filter(Boolean).join("  ·  ")
  const state = agent.since > 0
    ? `${STATE_NAMES[agent.state]} · ${formatElapsed(agent.since)}`
    : STATE_NAMES[agent.state]

  return [
    Widget.Box({
      css_classes: ["agent-menu-icon", agent.state],
      valign: Gtk.Align.CENTER,
      children: [icon],
    }),
    Widget.Box({
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 2,
      hexpand: true,
      valign: Gtk.Align.CENTER,
      children: [
        Widget.Label({
          css_classes: ["agent-menu-title"],
          label: title,
          xalign: 0,
          ellipsize: Pango.EllipsizeMode.END,
          max_width_chars: 28,
        }),
        Widget.Label({
          css_classes: ["agent-menu-subtitle"],
          label: subtitle,
          visible: subtitle !== "",
          xalign: 0,
          ellipsize: Pango.EllipsizeMode.MIDDLE,
          max_width_chars: 40,
        }),
      ],
    }),
    Widget.Label({ css_classes: ["agent-menu-state", agent.state], label: state, valign: Gtk.Align.CENTER }),
  ]
}

function MenuBody(agent: Agent): Gtk.Widget[] {
  const hook = agent.hook
  if (!hook) return []

  const sections: Gtk.Widget[] = []
  const reason = hook.approval_reason || hook.notification_message
  if (agent.state === "waiting" && reason) {
    const caption = hook.approval_reason ? "Approval needed" : "Notification"
    sections.push(Section(caption, Text(oneLine(reason), 3), ["agent-menu-callout", "waiting"]))
  }
  if (hook.error) sections.push(Section("Error", Text(oneLine(hook.error), 3), ["agent-menu-callout", "error"]))
  if (hook.prompt) sections.push(Section("Prompt", Text(oneLine(hook.prompt), 3)))

  const lastResponse = agent.state === "idle" ? hook.last_assistant_message : undefined
  if (lastResponse) {
    sections.push(Section("Last response", Text(plainText(oneLine(lastResponse)), 4)))
  } else if (hook.tool_name) {
    const caption = agent.state === "idle" ? "Last tool" : "Tool"
    const count = hook.tool_count ? ` · #${hook.tool_count}` : ""
    sections.push(Section(caption + count, ToolBlock(hook)))
  }

  const tasks = TASK_KINDS.flatMap(([kind, suffix]) =>
    (hook.background_tasks ?? []).filter(task => task.kind === kind).map(task => `${suffix} · ${task.description}`))
  if (tasks.length > 0) sections.push(Section("Background", Text(tasks.join("\n"), 6)))
  return sections
}

function metaLine(agent: Agent): string {
  // An idle agent's last update is when it went idle, which the state chip shows.
  const updatedAt = agent.hook && agent.state !== "idle" ? Date.parse(agent.hook.updated_at) : Number.NaN
  return [
    agent.hook?.model,
    !agent.hook && agent.toolCount ? `${agent.toolCount} tool calls` : "",
    Number.isNaN(updatedAt) ? "" : `updated ${formatElapsed(updatedAt)} ago`,
  ].filter(Boolean).join(" · ")
}

function ActionButton(icon: string, label: string, tooltip: string, onClicked: () => void, classes: string[] = []): Gtk.Button {
  return Widget.Button({
    css_classes: ["agent-menu-action", ...classes],
    tooltip_text: tooltip,
    onClicked,
    child: Widget.Box({
      spacing: 6,
      children: [Widget.Image({ iconName: icon }), Widget.Label({ label })],
    }),
  })
}

function AgentMenu(initial: Agent, parent: Gtk.Widget): Gtk.Popover {
  let agent = initial
  const popover = new Gtk.Popover()

  const header = Widget.Box({ css_classes: ["agent-menu-header"], spacing: 10 })
  const body = Widget.Box({ css_classes: ["agent-menu-body"], orientation: Gtk.Orientation.VERTICAL, spacing: 12 })
  const meta = Widget.Label({ css_classes: ["agent-menu-meta"], xalign: 0, hexpand: true, ellipsize: Pango.EllipsizeMode.END })

  const act = (action: (agent: Agent) => void) => () => {
    popover.popdown()
    action(agent)
  }
  const interrupted = ActionButton(
    "media-playback-stop-symbolic",
    "Interrupted",
    "Mark idle: interrupting a turn with Esc fires no hook",
    act(target => markAgentIdle(target.key)),
    ["interrupt"],
  )
  const remove = ActionButton(
    "view-conceal-symbolic",
    "Remove",
    "Hide until this agent's state changes",
    act(dismissAgent),
  )

  const render = () => {
    replaceChildren(header, MenuHeader(agent))
    const sections = MenuBody(agent)
    replaceChildren(body, sections)
    body.visible = sections.length > 0
    meta.label = metaLine(agent)
    interrupted.visible = agent.hook !== null && agent.state !== "idle"
  }
  render()

  // The bar keeps its pills frozen while the menu is open, so the menu follows the
  // agent on its own.
  const refresh = () => {
    const fresh = agents.get().find(candidate => candidate.key === agent.key)
    if (!fresh) return popover.popdown()
    agent = fresh
    render()
  }
  let unsubscribe: (() => void)[] = []
  popover.connect("map", () => {
    unsubscribe = [agents.subscribe(refresh), agentClock.subscribe(refresh)]
    openMenus += 1
    agentMenuOpen.set(true)
  })
  popover.connect("unmap", () => {
    for (const stop of unsubscribe) stop()
    unsubscribe = []
    openMenus -= 1
    agentMenuOpen.set(openMenus > 0)
  })
  popover.connect("closed", () => {
    GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
      if (popover.get_parent() !== null) popover.unparent()
      return GLib.SOURCE_REMOVE
    })
  })

  popover.set_child(Widget.Box({
    css_classes: ["agent-menu"],
    orientation: Gtk.Orientation.VERTICAL,
    children: [
      header,
      body,
      Widget.Box({ css_classes: ["agent-menu-footer"], spacing: 4, children: [meta, interrupted, remove] }),
    ],
  }))
  popover.set_parent(parent)
  // Popover expand propagates from its content and would stretch the pill.
  popover.set_hexpand(false)
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
    "Click: focus · Right-click: menu",
  ].filter(Boolean).join("\n")

  const pill = Widget.Box({
    css_classes: ["agent-session-pill", `agent-session-${agent.state}`, `agent-${agent.id}`],
    tooltip_text: tooltip,
    children: [
      icon,
      Widget.Label({ css_classes: ["agent-session-name"], label: pillLabel(agent) }),
      ...(badge ? [badge] : []),
      ...TaskBadges(agent.hook),
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
    AgentMenu(fresh, pill).popup()
  })
  pill.add_controller(rightClick)

  return pill
}
