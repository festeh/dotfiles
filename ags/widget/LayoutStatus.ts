import { Widget } from "astal/gtk4"
import { Variable, bind } from "astal"
import { keyboardLayout } from "./Menu"
import GLib from "gi://GLib"

export default function LayoutStatus() {
  return Widget.Button({
    css_classes: ["layout-status-widget"],
    margin: 0,
    visible: bind(keyboardLayout).as(layout => layout.includes("Russian")),
    child: Widget.Image({
      file: "/home/dima/dotfiles/ags/assets/ru-tricolor.svg",
    }),
    onClicked: () => {
      GLib.spawn_command_line_async("hyprctl switchxkblayout at-translated-set-2-keyboard next")
    },
  })
}
