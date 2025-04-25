import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"
import Wp from "gi://AstalWp"


export default function Volume() {
  const speaker = Wp.get_default()?.audio.defaultSpeaker!
  const muted = bind(speaker, "mute")
  return new Widget.Box({
    className: "volume-widget",
    children: [
      new Widget.Button({
        className: bind(muted).as(m => m ? "muted" : ""),
        child: new Widget.Icon({
          icon: bind(muted).as(m =>
            m ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
          ),
        }),
        onClicked: () => {
          speaker.mute = !speaker.mute
        },
      }),
      new Widget.Label({
        label: bind(speaker, "volume").as(v => `${Math.round(v * 100)}%`),
      }),
      new Widget.Button({
        child: new Widget.Icon("audio-volume-low-symbolic"), // Or use a "-" icon if available
        onClicked: () => {
          speaker.volume = Math.max(0, speaker.volume - 0.05); // Decrease by 5%
        },
      }),
      // new Widget.Button({
      //   child: new Widget.Icon("audio-volume-high-symbolic"), // Or use a "+" icon if available
      //   onClicked: () => {
      //     speaker.volume = Math.min(1, speaker.volume + 0.05); // Increase by 5%
      //   },
      // }),
    ],
  })
}
