import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"
import GLib from "gi://GLib"

function getVolume(): number {
  try {
    const [success, stdout, stderr] = GLib.spawn_command_line_sync("pamixer --get-volume")
    return parseInt(stdout.toString())
  } catch (error) {
    return 0
  }
}

function isMuted(): boolean {
  try {
    const [success, stdout, stderr] = GLib.spawn_command_line_sync("pamixer --get-mute")
    return stdout.toString().trim() === "true"
  } catch (error) {
    return false
  }
}

const volume = Variable<number>(getVolume()).poll(1000, () => getVolume())
const muted = Variable<boolean>(isMuted()).poll(1000, () => isMuted())

export default function Volume() {
  return new Widget.Box({
    className: "volume-widget",
    children: [
      new Widget.Button({
        child: new Widget.Icon({
          icon: bind(muted).as(m => 
            m ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
          ),
          size: 16,
        }),
        onClicked: () => {
          GLib.spawn_command_line_async("pamixer -t")
        },
      }),
      // new Widget.Slider({
      //   hexpand: true,
      //   value: bind(volume).as(v => v / 100),
      //   onChange: ({ value }) => {
      //     GLib.spawn_command_line_async(`pamixer --set-volume ${Math.round(value * 100)}`)
      //   },
      // }),
    ],
  })
}
