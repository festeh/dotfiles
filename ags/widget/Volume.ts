import { Widget } from "astal/gtk4"
import { bind } from "astal"
import Wp from "gi://AstalWp"


export default function Volume() {
  const speaker = Wp.get_default()?.audio.defaultSpeaker!
  const muted = bind(speaker, "mute")
  return Widget.Box({
    css_classes: ["volume-widget"],
    children: [
      Widget.Button({
        css_classes: bind(muted).as(m => m ? ["muted"] : []),
        child: Widget.Image({
          iconName: bind(muted).as(m =>
            m ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
          ),
        }),
        onClicked: () => {
          speaker.mute = !speaker.mute
        },
      }),
      Widget.Button({
        className: "volume-button-minus",
        child: Widget.Image({ iconName: "list-remove-symbolic" }), // Use minus icon
        onClicked: () => {
          speaker.volume = Math.max(0, speaker.volume - 0.05); // Decrease by 5%
        },
      }),
      Widget.Button({
        className: "volume-button-plus",
        child: Widget.Image({ iconName: "list-add-symbolic" }), // Use plus icon
        onClicked: () => {
          speaker.volume = Math.min(1, speaker.volume + 0.05); // Increase by 5%
        },
      }),
      Widget.Label({
        label: bind(speaker, "volume").as(v => `${Math.round(v * 100)}%`),
      }),
    ],
  })
}
