import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"
import GLib from "gi://GLib"
import Wp from "gi://AstalWp"

function getVolume(): number {
  try {
    const [success, stdout, stderr] = GLib.spawn_command_line_sync("wpctl get-volume @DEFAULT_AUDIO_SINK@")
    const match = stdout.toString().match(/\d+\.\d+/)
    return match ? Math.round(parseFloat(match[0]) * 100) : 0
  } catch (error) {
    return 0
  }
}

const volume = Variable<number>(getVolume()).poll(1000, () => getVolume())

export default function Volume() {
  const speaker = Wp.get_default()?.audio.defaultSpeaker!
  const muted = bind(speaker, "mute")
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
          speaker.mute = !speaker.mute
        },
      }),
      new Widget.Slider({
        hexpand: true,
        value: bind(speaker, "volume"),
        onDragged: (value) => speaker.volume = value,
      }),
    ],
  })
}
