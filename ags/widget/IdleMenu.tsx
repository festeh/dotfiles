import { App, Astal, Gdk, Gtk } from "astal/gtk4"
import { Variable, bind } from "astal"
import { Widget } from "astal/gtk4"
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

export default function IdleMenu(monitor: Gdk.Monitor, visible: Variable<boolean>) {
  return (
    <window
      gdkmonitor={monitor}
      cssClasses={["IdleMenu"]}
      visible={bind(visible)}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
      application={App}>
      <box
        cssClasses={["idle-menu-widget"]}
        spacing={5}
        orientation={Gtk.Orientation.VERTICAL}
      >
        <button
          css_classes={bind(isIdleRunning).as(running =>
            running ? ["idle-toggle-button"] : ["idle-toggle-button", "idle-toggle-button-inactive"]
          )}
          onClicked={() => {
            const running = isIdleRunning.get()
            if (running) {
              GLib.spawn_command_line_async("pkill swayidle")
            } else {
              GLib.spawn_command_line_async('bash -c "swayidle -w timeout 1500 \'systemctl hibernate\' &"')
            }
          }}
        >
          <box spacing={10}>
            <image
              iconName={bind(isIdleRunning).as(running =>
                running ? "face-plain-symbolic" : "face-surprise-symbolic"
              )}
              css="font-size: 18px"
            />
            <label
              label={bind(isIdleRunning).as(running =>
                running ? "Idle Monitor Active" : "Idle Monitor Inactive"
              )}
            />
          </box>
        </button>
      </box>
    </window>
  )
}

export { isIdleRunning }
