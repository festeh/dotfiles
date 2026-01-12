import Hyprland from "gi://AstalHyprland"
import { exec, execAsync } from "astal"

class WorkspaceNamingService {
  private hypr = Hyprland.get_default()

  constructor() {
    // Track previous workspace of windows for move detection
    const windowWorkspaces = new Map<string, number>()

    this.hypr.connect("event", (_, eventName, args) => {
      const parts = args.split(",")

      switch (eventName) {
        case "movewindowv2": {
          const address = parts[0]
          const destWorkspaceId = parseInt(parts[1])
          const sourceWorkspaceId = windowWorkspaces.get(address)

          if (sourceWorkspaceId) this.updateWorkspaceName(sourceWorkspaceId)
          this.updateWorkspaceName(destWorkspaceId)

          windowWorkspaces.set(address, destWorkspaceId)
          break
        }

        case "activewindowv2": {
          const client = this.hypr.get_client(parts[0])
          const workspace = client?.get_workspace()
          if (client && workspace) {
            const wsId = workspace.get_id()
            this.updateWorkspaceName(wsId)
            windowWorkspaces.set(parts[0], wsId)
          }
          break
        }

        case "closewindow": {
          this.updateAllWorkspaceNames()
          windowWorkspaces.delete(parts[0])
          break
        }
      }
    })

    // Initial sync on startup
    this.updateAllWorkspaceNames()
  }

  private async getKittyCwd(pid: number): Promise<string | null> {
    try {
      const output = await execAsync(`kitty @ --to unix:@kitty-${pid} ls`)
      const data = JSON.parse(output)
      const cwd = data[0]?.tabs?.[0]?.windows?.[0]?.cwd
      return cwd || null
    } catch {
      return null
    }
  }

  private async updateWorkspaceName(workspaceId: number) {
    const workspace = this.hypr.get_workspace(workspaceId)
    if (!workspace) return

    // Find kitty client in this workspace
    const kittyClient = this.hypr.get_clients().find(
      (client) => client.get_workspace()?.get_id() === workspaceId &&
                  client.get_class() === "kitty"
    )

    let newName = workspaceId.toString()

    if (kittyClient) {
      const cwd = await this.getKittyCwd(kittyClient.get_pid())
      if (cwd) {
        const parts = cwd.split("/")
        newName = parts[parts.length - 1] || workspaceId.toString()
      }
    }

    if (workspace.get_name() !== newName) {
      exec(`hyprctl dispatch renameworkspace ${workspaceId} ${newName}`)
    }
  }

  private async updateAllWorkspaceNames() {
    const workspaces = this.hypr.get_workspaces()
      .filter((ws) => !(ws.get_id() >= -99 && ws.get_id() <= -2))

    for (const workspace of workspaces) {
      await this.updateWorkspaceName(workspace.get_id())
    }
  }
}

export default new WorkspaceNamingService()
