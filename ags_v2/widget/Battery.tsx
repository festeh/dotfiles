import AstalBattery from "gi://AstalBattery?version=0.1"

import { Gtk, Gdk, Widget, astalify, type ConstructProps } from "astal/gtk3"
import { bind } from "astal"

export default function Battery() {
  const bat = AstalBattery.get_default()
  return new Widget.Box({
    children: [
      new Widget.Icon({
        icon: bind(bat, "icon-name"),
      }),
      new Widget.Label({
        label: bind(bat, "percentage").as((p) => {
          return `${Math.round(p * 100)}%`
        }),
      }),
    ],
  })
}
