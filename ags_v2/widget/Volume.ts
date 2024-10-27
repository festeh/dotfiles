import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"
import GLib from "gi://GLib"

function getVolume(): number {
  try {
    const [success, stdout, stderr] = GLib.spawn_command_line_sync("wpctl get-volume @DEFAULT_AUDIO_SINK@")
    const match = stdout.toString().match(/\d+\.\d+/)
    return match ? Math.round(parseFloat(match[0]) * 100) : 0
  } catch (error) {
    return 0
  }
}

function isMuted(): boolean {
  try {
    const [success, stdout, stderr] = GLib.spawn_command_line_sync("wpctl get-volume @DEFAULT_AUDIO_SINK@")
    return stdout.toString().includes("MUTED")
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
          GLib.spawn_command_line_async("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
        },
      }),
      // new Widget.Slider({
      //   hexpand: true,
      //   value: bind(volume).as(v => v / 100),
      //   onChange: ({ value }) => {
      //     GLib.spawn_command_line_async(`wpctl set-volume @DEFAULT_AUDIO_SINK@ ${value.toFixed(2)}`)
      //   },
      // }),
    ],
  })
}
