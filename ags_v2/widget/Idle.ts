import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"
import GLib from "gi://GLib"

function checkSwayidle(): boolean {
  try {
    const [success, stdout, stderr] = GLib.spawn_command_line_sync("pgrep swayidle")
    return stdout.length > 0
  } catch (error) {
    return false
  }
}

const isIdleRunning = Variable<boolean>(checkSwayidle()).poll(1000, () => checkSwayidle())

export default function Idle() {
  return new Widget.Button({
    className: bind(isIdleRunning).as(running => 
      running ? "idle-widget" : "idle-widget idle-widget-inactive"
    ),
    child: new Widget.Icon({
      icon: bind(isIdleRunning).as(running => 
        running ? "face-plain-symbolic" : "face-surprise-symbolic"
      ),
    }),
    onClicked: () => {
      const running = isIdleRunning.get()
      if (running) {
        GLib.spawn_command_line_async("pkill swayidle")
      } else {
        GLib.spawn_command_line_async('bash -c "swayidle -w timeout 1500 \'systemctl hibernate\' &"')
      }
    },
  })
}
