const hyprland = await Service.import("hyprland")

export function Workspaces() {
  const activeId = hyprland.active.workspace.bind("id").as(i => i.toString())
  const workspaces = ['1', '2', '3', '4', '5', '6', '7', '8', '9']
  // return Widget.Box({
  //   children: 
  // })
  const widget = Widget.Label({
    label: activeId
  })
  return widget
}
