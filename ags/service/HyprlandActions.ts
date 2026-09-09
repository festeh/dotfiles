import Hyprland from "gi://AstalHyprland"

function luaString(value: string): string {
  const escaped = value.replace(/[\\"\x00-\x1f\x7f]/g, char =>
    `\\${char.charCodeAt(0).toString().padStart(3, "0")}`,
  )
  return `"${escaped}"`
}

function dispatch(expression: string): void {
  // With a Lua config, Hyprland expects a dispatcher expression. Astal's
  // workspace.focus() still sends the old "workspace <id>" syntax.
  Hyprland.get_default().dispatch(expression, "")
}

export function focusWorkspace(workspaceId: number): void {
  dispatch(`hl.dsp.focus({ workspace = ${workspaceId} })`)
}

export function renameWorkspace(workspaceId: number, name: string): void {
  dispatch(`hl.dsp.workspace.rename({ workspace = ${workspaceId}, name = ${luaString(name)} })`)
}
