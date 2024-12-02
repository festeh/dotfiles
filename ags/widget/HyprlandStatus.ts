
import Hyprland from "gi://AstalHyprland"
import { Widget } from "astal/gtk3"
import { bind } from "astal"


export default function HyprlandStatus() {
  const hypr = Hyprland.get_default()
  const workspace = bind(hypr, "focusedWorkspace").as((ws) => ws.get_name())
  return new Widget.Label({ 
    className: "workspace-widget",
    label: workspace 
  })
}
