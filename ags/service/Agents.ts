import { Variable } from "astal"
import Gio from "gi://Gio"
import GLib from "gi://GLib"
import Hyprland from "gi://AstalHyprland"
import { focusWorkspace } from "./HyprlandActions"

// An agent pill exists while a Kitty window's foreground process is a known agent
// (`kitty @ ls`). Hook-driven agents add state through ~/.cache/ags-agents/windows,
// written by ags/hooks/agent_status.py. Codex hooks run in a shared app-server
// daemon that cannot tell which window a session belongs to, so Codex state comes
// from the terminal title its TUI maintains.

export type AgentId = "claude" | "codex" | "kimi"
export type AgentState = "idle" | "running" | "waiting" | "compacting"

/** One window's hook state; see ags/hooks/agent_status.py. */
export interface AgentHookState {
  agent: AgentId
  session_id: string
  state: AgentState
  state_since: string
  updated_at: string
  cwd?: string
  git_branch?: string
  model?: string
  prompt?: string
  tool_name?: string
  tool_detail?: string
  tool_count?: number
  error?: string
  approval_reason?: string
  notification_message?: string
  last_assistant_message?: string
  agent_type?: string
}

export interface Agent {
  key: string
  id: AgentId
  state: AgentState
  /** Epoch ms when the current state began. */
  since: number
  title: string
  tabTitle: string
  cwd: string
  windowAddress: string
  kittyPid: number
  windowId: number
  order: number
  hook: AgentHookState | null
}

interface AgentKind {
  id: AgentId
  stateSource: "hooks" | "title"
  matches: (argv: string[]) => boolean
}

interface KittyProcess {
  pid?: number
  cwd?: string
  cmdline?: string[]
}

interface KittyWindow {
  id?: number
  title?: string
  cwd?: string
  foreground_processes?: KittyProcess[]
}

interface KittyTab {
  title?: string
  windows?: KittyWindow[]
}

interface KittyOsWindow {
  tabs?: KittyTab[]
}

interface AgentWindow {
  key: string
  kind: AgentKind
  title: string
  tabTitle: string
  cwd: string
  windowAddress: string
  kittyPid: number
  windowId: number
  order: number
}

const POLL_INTERVAL_MS = 5000
const WINDOWS_DIR = GLib.get_home_dir() + "/.cache/ags-agents/windows"
const ASSETS_DIR = GLib.get_home_dir() + "/dotfiles/ags/assets"

// Codex blinks between "[ ! ]" and "[ . ]" every second while it needs input.
const ACTION_REQUIRED_RE = /^\[\s*[!.]\s*\]\s*Action Required(?:\s*\|\s*)?/i
// Braille spinners (Codex, older Claude), ◐◑◒◓ (Claude working), ✳ (Claude idle).
const ACTIVITY_GLYPHS_RE = /^[\s⠀-⣿◐-◓✳]+/u

function basename(path: string): string {
  return path.slice(path.lastIndexOf("/") + 1)
}

const AGENT_KINDS: AgentKind[] = [
  { id: "claude", stateSource: "hooks", matches: argv => basename(argv[0] || "") === "claude" },
  { id: "kimi", stateSource: "hooks", matches: argv => basename(argv[0] || "") === "kimi" },
  {
    id: "codex",
    stateSource: "title",
    matches: argv => {
      const command = basename(argv[0] || "")
      const isCodex = command === "codex" || (command === "node" && basename(argv[1] || "") === "codex.js")
      return isCodex && !argv.some(arg => arg === "app-server" || arg === "exec-server")
    },
  },
]

const hypr = Hyprland.get_default()
export const agents = Variable<Agent[]>([])
export const agentClock = Variable(0)

let windows: AgentWindow[] = []
let hookStates = new Map<string, AgentHookState>()
const observedStates = new Map<string, { state: AgentState, since: number }>()
const kittyCommByPid = new Map<number, boolean>()
// Unknown windows whose state file already triggered an early poll this interval.
const pollTriggeredKeys = new Set<string>()

Gio._promisify(Gio.Subprocess.prototype, "communicate_utf8_async", "communicate_utf8_finish")

export function agentIcon(id: AgentId): string {
  return `${ASSETS_DIR}/${id}.svg`
}

function titleState(title: string): AgentState {
  const trimmed = title.trimStart()
  if (ACTION_REQUIRED_RE.test(trimmed)) return "waiting"
  if (/^[⠁-⣿]/u.test(trimmed)) return "running"
  return "idle"
}

function stripActivity(title: string): string {
  return title.trimStart().replace(ACTION_REQUIRED_RE, "").replace(ACTIVITY_GLYPHS_RE, "").trim()
}

function isKittyClient(client: ReturnType<typeof hypr.get_clients>[number]): boolean {
  if ((client.get_class() || "").toLowerCase() === "kitty") return true

  const pid = client.get_pid()
  let isKitty = kittyCommByPid.get(pid)
  if (isKitty === undefined) {
    try {
      const [ok, content] = GLib.file_get_contents(`/proc/${pid}/comm`)
      isKitty = ok && new TextDecoder().decode(content).trim() === "kitty"
    } catch {
      isKitty = false
    }
    kittyCommByPid.set(pid, isKitty)
  }
  return isKitty
}

async function kittyLayout(pid: number): Promise<KittyOsWindow[] | null> {
  try {
    const process = Gio.Subprocess.new(
      ["timeout", "1s", "kitty", "@", "--to", `unix:@kitty-${pid}`, "ls"],
      Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE,
    )
    const [stdout] = await process.communicate_utf8_async(null, null)
    if (!process.get_successful()) return null
    const layout = JSON.parse(stdout)
    return Array.isArray(layout) ? layout : null
  } catch {
    return null
  }
}

function stateSince(key: string, state: AgentState, hook: AgentHookState | null, now: number): number {
  const hookSince = hook ? Date.parse(hook.state_since) : Number.NaN
  if (!Number.isNaN(hookSince)) return hookSince

  const observed = observedStates.get(key)
  if (observed?.state === state) return observed.since
  observedStates.set(key, { state, since: now })
  return now
}

function publish(): void {
  const now = Date.now()
  const next = windows.map((window): Agent => {
    const file = hookStates.get(window.key)
    const hook = file?.agent === window.kind.id ? file : null
    const state = window.kind.stateSource === "title"
      ? titleState(window.title)
      : hook?.state ?? "idle"

    return {
      key: window.key,
      id: window.kind.id,
      state,
      since: stateSince(window.key, state, hook, now),
      title: stripActivity(window.title),
      tabTitle: stripActivity(window.tabTitle),
      cwd: hook?.cwd || window.cwd,
      windowAddress: window.windowAddress,
      kittyPid: window.kittyPid,
      windowId: window.windowId,
      order: window.order,
      hook,
    }
  })

  for (const key of observedStates.keys()) {
    if (!windows.some(window => window.key === key)) observedStates.delete(key)
  }
  if (JSON.stringify(next) !== JSON.stringify(agents.get())) agents.set(next)
}

let polling = false
let pollAgain = false

async function pollKitty(): Promise<void> {
  if (polling) {
    pollAgain = true
    return
  }

  polling = true
  try {
    const clients = hypr.get_clients().filter(isKittyClient)
    for (const pid of kittyCommByPid.keys()) {
      if (!clients.some(client => client.get_pid() === pid)) kittyCommByPid.delete(pid)
    }

    const clientsPerPid = new Map<number, number>()
    for (const client of clients) {
      clientsPerPid.set(client.get_pid(), (clientsPerPid.get(client.get_pid()) || 0) + 1)
    }

    const layouts = await Promise.all(clients.map(client => kittyLayout(client.get_pid())))
    const found: AgentWindow[] = []
    clients.forEach((client, clientIndex) => {
      const layout = layouts[clientIndex]
      const kittyPid = client.get_pid()
      // Kitty reports no platform window id on Wayland, so a layout can only be
      // tied to a Hyprland window when its process owns exactly one OS window.
      if (!layout || layout.length !== 1 || clientsPerPid.get(kittyPid) !== 1) return

      for (const [tabIndex, tab] of (layout[0].tabs || []).entries()) {
        for (const [windowIndex, window] of (tab.windows || []).entries()) {
          if (typeof window.id !== "number") continue
          for (const process of window.foreground_processes || []) {
            const kind = AGENT_KINDS.find(candidate => candidate.matches(process.cmdline || []))
            if (!kind) continue
            found.push({
              key: `${kittyPid}-${window.id}`,
              kind,
              title: window.title || "",
              tabTitle: tab.title || "",
              cwd: process.cwd || window.cwd || "",
              windowAddress: client.get_address(),
              kittyPid,
              windowId: window.id,
              order: clientIndex * 1000000 + tabIndex * 1000 + windowIndex,
            })
            break
          }
        }
      }
    })

    windows = found
    publish()
  } catch (error) {
    console.error("Could not read Kitty agent windows:", error)
  } finally {
    polling = false
    if (pollAgain) {
      pollAgain = false
      void pollKitty()
    }
  }
}

function readHookStates(): void {
  const states = new Map<string, AgentHookState>()
  try {
    const enumerator = Gio.File.new_for_path(WINDOWS_DIR)
      .enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null)
    let info: Gio.FileInfo | null
    while ((info = enumerator.next_file(null)) !== null) {
      const name = info.get_name()
      if (!name.endsWith(".json")) continue
      try {
        const [ok, content] = GLib.file_get_contents(`${WINDOWS_DIR}/${name}`)
        if (ok) states.set(name.slice(0, -".json".length), JSON.parse(new TextDecoder().decode(content)))
      } catch {}
    }
    enumerator.close(null)
  } catch {}

  hookStates = states
  publish()
}

let hookReadSource = 0

function scheduleHookRead(): void {
  if (hookReadSource !== 0) return
  hookReadSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
    hookReadSource = 0
    readHookStates()
    return GLib.SOURCE_REMOVE
  })
}

export function agentWorkspaceId(agent: Agent): number | null {
  return hypr.get_client(agent.windowAddress)?.get_workspace()?.get_id() ?? null
}

export function focusAgent(agent: Agent): void {
  const workspaceId = agentWorkspaceId(agent)
  if (workspaceId === null) return
  focusWorkspace(workspaceId)

  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
    try {
      Gio.Subprocess.new(
        ["kitty", "@", "--to", `unix:@kitty-${agent.kittyPid}`, "focus-window", "--match", `id:${agent.windowId}`, "--no-response"],
        Gio.SubprocessFlags.STDOUT_SILENCE | Gio.SubprocessFlags.STDERR_SILENCE,
      )
    } catch {}
    return GLib.SOURCE_REMOVE
  })
}

// Assigned inside a function on purpose: AGS runs its main loop after module
// evaluation, and a top-level const that no function captures is then garbage
// collected, which silently stops the monitor.
let hookMonitor: Gio.FileMonitor | null = null

function watchHookStates(): void {
  GLib.mkdir_with_parents(WINDOWS_DIR, 0o755)
  hookMonitor = Gio.File.new_for_path(WINDOWS_DIR).monitor_directory(Gio.FileMonitorFlags.NONE, null)
  hookMonitor.connect("changed", (_monitor, file) => {
    // Hooks write <key>.json.<pid>.tmp and rename it to <key>.json.
    const key = /^(\d+-\d+)\.json/.exec(file.get_basename() || "")?.[1]
    if (key === undefined) return

    // A state file for a window we have not seen yet means an agent just started.
    if (!windows.some(window => window.key === key) && !pollTriggeredKeys.has(key)) {
      pollTriggeredKeys.add(key)
      void pollKitty()
    }
    scheduleHookRead()
  })
}

watchHookStates()

hypr.connect("client-added", () => { void pollKitty() })
hypr.connect("client-removed", () => { void pollKitty() })
GLib.timeout_add(GLib.PRIORITY_DEFAULT, POLL_INTERVAL_MS, () => {
  pollTriggeredKeys.clear()
  void pollKitty()
  agentClock.set(agentClock.get() + 1)
  return GLib.SOURCE_CONTINUE
})

readHookStates()
void pollKitty()
