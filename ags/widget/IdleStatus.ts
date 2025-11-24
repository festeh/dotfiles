import { Widget } from "astal/gtk4"
import { Variable, bind } from "astal"
import { isIdleRunning } from "./Menu"
import GLib from "gi://GLib"

export default function IdleStatus() {
  return Widget.Button({
    css_classes: ["idle-status-widget"],
    margin: 0,
    visible: bind(isIdleRunning).as(running => !running),
    child: Widget.Image({
      iconName: "face-surprise-symbolic",
      css: "font-size: 18px",
      margin: 0
    }),
    onClicked: () => {
      GLib.spawn_command_line_async('bash -c "swayidle -w timeout 1500 \'systemctl hibernate\' &"')
    },
  })
}
