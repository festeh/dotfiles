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
      new Widget.Slider({
        value: bind(speaker, "volume"),
        // hexpand: true,
        // drawValue: false,
        // min: 0,
        // max: 1,
        // step: 0.1,
        // digits: 3,
        onDragged: (slider) => {
          const value = slider.value
          speaker.volume = value
        },
      }),
    ],
  })
}
