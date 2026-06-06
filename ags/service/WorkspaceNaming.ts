import Hyprland from "gi://AstalHyprland"
import Gio from "gi://Gio"
import GLib from "gi://GLib"

const KITTY_REQUEST_TIMEOUT_MS = 1500
const WORKSPACE_UPDATE_DELAY_MS = 150

Gio._promisify(Gio.SocketClient.prototype, "connect_async", "connect_finish")
Gio._promisify(Gio.InputStream.prototype, "read_bytes_async", "read_bytes_finish")

interface KittyWindow {
  cwd?: string
}

interface KittyTab {
  windows?: KittyWindow[]
}

interface KittyOsWindow {
  tabs?: KittyTab[]
}

interface KittyClientRef {
  address: string
  pid: number
}

class WorkspaceNamingService {
  private hypr = Hyprland.get_default()
  private textEncoder = new TextEncoder()
  private textDecoder = new TextDecoder()
  private scheduledUpdates = new Map<number, number>()
  private runningUpdates = new Set<number>()
  private rerunUpdates = new Set<number>()
  private windowWorkspaces = new Map<string, number>()
  private activeKittyByWorkspace = new Map<number, KittyClientRef>()

  constructor() {
    this.refreshWindowWorkspaceCache()
    this.refreshActiveKittyCache()

    this.hypr.connect("event", (_, eventName, args) => {
      const parts = args.split(",")

      switch (eventName) {
        case "workspacev2":
        case "focusedmon": {
          this.scheduleFocusedWorkspaceUpdate()
          break
        }

        case "openwindow": {
          const client = this.clientByAddress(parts[0])
          const workspaceId = client?.get_workspace()?.get_id()
          if (workspaceId !== undefined) {
            this.windowWorkspaces.set(normalizeAddress(parts[0]), workspaceId)
            this.syncActiveKittyForWorkspace(workspaceId)
            this.scheduleWorkspaceUpdate(workspaceId)
          }
          break
        }

        case "movewindowv2": {
          const address = normalizeAddress(parts[0])
          const destWorkspaceId = parseInt(parts[1], 10)
          const sourceWorkspaceId = this.windowWorkspaces.get(address)

          if (sourceWorkspaceId !== undefined) this.scheduleWorkspaceUpdate(sourceWorkspaceId)
          if (!Number.isNaN(destWorkspaceId)) {
            if (sourceWorkspaceId !== undefined) {
              this.syncActiveKittyForWorkspace(sourceWorkspaceId)
            }
            this.syncActiveKittyForWorkspace(destWorkspaceId)
            this.scheduleWorkspaceUpdate(destWorkspaceId)
            this.windowWorkspaces.set(address, destWorkspaceId)
          }

          break
        }

        case "activewindowv2": {
          const client = this.clientByAddress(parts[0])
          const workspace = client?.get_workspace()
          if (client && workspace) {
            const wsId = workspace.get_id()
            this.syncActiveKittyForWorkspace(wsId)
            this.scheduleWorkspaceUpdate(wsId)
            this.windowWorkspaces.set(normalizeAddress(parts[0]), wsId)
          }
          break
        }

        case "windowtitlev2": {
          const client = this.clientByAddress(parts[0])
          if (client?.get_class() !== "kitty") break

          const workspaceId = client.get_workspace()?.get_id()
          if (workspaceId !== undefined) {
            const activeKitty = this.syncActiveKittyForWorkspace(workspaceId)
            if (activeKitty?.address === normalizeAddress(client.get_address())) {
              this.scheduleWorkspaceUpdate(workspaceId)
            }
          }
          break
        }

        case "closewindow": {
          const address = normalizeAddress(parts[0])
          const workspaceId = this.windowWorkspaces.get(address)
          if (workspaceId !== undefined) {
            this.syncActiveKittyForWorkspace(workspaceId)
            this.scheduleWorkspaceUpdate(workspaceId)
          }
          this.windowWorkspaces.delete(address)
          break
        }
      }
    })

    // Initial sync on startup
    this.updateAllWorkspaceNames()
  }

  private refreshWindowWorkspaceCache() {
    this.windowWorkspaces.clear()
    for (const client of this.hypr.get_clients()) {
      const workspaceId = client.get_workspace()?.get_id()
      if (workspaceId !== undefined) {
        this.windowWorkspaces.set(normalizeAddress(client.get_address()), workspaceId)
      }
    }
  }

  private refreshActiveKittyCache() {
    this.activeKittyByWorkspace.clear()
    for (const workspace of this.hypr.get_workspaces()) {
      if (!isSpecialWorkspace(workspace.get_id())) {
        this.syncActiveKittyForWorkspace(workspace.get_id())
      }
    }
  }

  private syncActiveKittyForWorkspace(workspaceId: number): KittyClientRef | null {
    const workspace = this.hypr.get_workspace(workspaceId)
    const client = workspace?.get_last_client()

    if (client?.get_class() === "kitty") {
      const activeKitty = {
        address: normalizeAddress(client.get_address()),
        pid: client.get_pid(),
      }
      this.activeKittyByWorkspace.set(workspaceId, activeKitty)
      return activeKitty
    }

    this.activeKittyByWorkspace.delete(workspaceId)
    return null
  }

  private clientByAddress(address: string) {
    return this.hypr.get_client(normalizeAddress(address)) || this.hypr.get_client(address)
  }

  private scheduleFocusedWorkspaceUpdate() {
    const workspaceId = this.hypr.get_focused_workspace()?.get_id()
    if (workspaceId !== undefined) {
      this.syncActiveKittyForWorkspace(workspaceId)
      this.scheduleWorkspaceUpdate(workspaceId)
    }
  }

  private scheduleWorkspaceUpdate(workspaceId: number) {
    if (isSpecialWorkspace(workspaceId)) return

    const pending = this.scheduledUpdates.get(workspaceId)
    if (pending !== undefined) GLib.source_remove(pending)

    const sourceId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, WORKSPACE_UPDATE_DELAY_MS, () => {
      this.scheduledUpdates.delete(workspaceId)
      this.runWorkspaceUpdate(workspaceId)
      return GLib.SOURCE_REMOVE
    })
    this.scheduledUpdates.set(workspaceId, sourceId)
  }

  private async runWorkspaceUpdate(workspaceId: number) {
    if (this.runningUpdates.has(workspaceId)) {
      this.rerunUpdates.add(workspaceId)
      return
    }

    this.runningUpdates.add(workspaceId)
    try {
      await this.updateWorkspaceName(workspaceId)
    } catch (error) {
      console.error(`Failed to update workspace ${workspaceId}:`, error)
    } finally {
      this.runningUpdates.delete(workspaceId)

      if (this.rerunUpdates.delete(workspaceId)) {
        this.scheduleWorkspaceUpdate(workspaceId)
      }
    }
  }

  private async kittyRemoteLs(pid: number): Promise<KittyOsWindow[]> {
    const client = new Gio.SocketClient()
    client.set_timeout(Math.ceil(KITTY_REQUEST_TIMEOUT_MS / 1000))

    const socketName = this.textEncoder.encode(`kitty-${pid}`)
    const address = Gio.UnixSocketAddress.new_with_type(
      Array.from(socketName),
      Gio.UnixSocketAddressType.ABSTRACT,
    )

    const cancellable = new Gio.Cancellable()
    let timeoutActive = true
    const timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, KITTY_REQUEST_TIMEOUT_MS, () => {
      timeoutActive = false
      cancellable.cancel()
      return GLib.SOURCE_REMOVE
    })

    let connection: Gio.SocketConnection | null = null
    try {
      connection = await client.connect_async(address, cancellable)
      connection.get_socket().set_timeout(Math.ceil(KITTY_REQUEST_TIMEOUT_MS / 1000))

      const request = {
        cmd: "ls",
        version: [0, 0, 0],
        no_response: false,
        payload: { all_env_vars: false, match: "state:focused" },
      }

      const frame = `\x1bP@kitty-cmd${JSON.stringify(request)}\x1b\\`
      connection.get_output_stream().write_all(this.textEncoder.encode(frame), cancellable)
      connection.get_socket().shutdown(false, true)

      let response = ""
      while (true) {
        const bytes = await connection.get_input_stream().read_bytes_async(
          4096,
          GLib.PRIORITY_DEFAULT,
          cancellable,
        )
        const chunk = bytes.toArray()
        if (chunk.length === 0) break
        response += this.textDecoder.decode(chunk)
        if (response.includes("\x1b\\")) break
      }

      const match = response.match(/\x1bP@kitty-cmd([\s\S]*)\x1b\\/)
      if (!match) throw new Error("Kitty response did not contain a command frame")

      const parsed = JSON.parse(match[1])
      if (!parsed.ok) throw new Error(parsed.error || "Kitty remote command failed")

      return JSON.parse(parsed.data)
    } finally {
      if (timeoutActive) GLib.source_remove(timeoutId)
      try { connection?.close(null) } catch {}
    }
  }

  private async getKittyCwd(pid: number): Promise<string | null> {
    const data = await this.kittyRemoteLs(pid)
    const window = data[0]?.tabs?.[0]?.windows?.[0]
    return window?.cwd || null
  }

  private async updateWorkspaceName(workspaceId: number) {
    const workspace = this.hypr.get_workspace(workspaceId)
    if (!workspace) return

    const activeKitty = this.syncActiveKittyForWorkspace(workspaceId)
    let newName = workspaceId.toString()

    if (activeKitty) {
      const cwd = await this.getKittyCwd(activeKitty.pid)
      if (!cwd) return

      newName = basename(cwd)
      if (!newName) return
    }

    if (workspace.get_name() !== newName) {
      this.hypr.dispatch("renameworkspace", `${workspaceId} ${newName}`)
    }
  }

  private updateAllWorkspaceNames() {
    const workspaces = this.hypr.get_workspaces()
      .filter((ws) => !isSpecialWorkspace(ws.get_id()))

    for (const workspace of workspaces) {
      this.scheduleWorkspaceUpdate(workspace.get_id())
    }
  }
}

function normalizeAddress(address: string): string {
  return address.replace(/^0x/, "")
}

function isSpecialWorkspace(workspaceId: number): boolean {
  return workspaceId >= -99 && workspaceId <= -2
}

function basename(path: string): string {
  const trimmed = path.replace(/\/+$/, "")
  const normalized = trimmed || path
  const slash = normalized.lastIndexOf("/")
  return slash >= 0 ? normalized.slice(slash + 1) || normalized : normalized
}

export default new WorkspaceNamingService()
