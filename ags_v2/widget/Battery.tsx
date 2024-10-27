import AstalBattery from "gi://AstalBattery?version=0.1"

import { Gtk, Gdk, Widget, astalify, type ConstructProps } from "astal/gtk3"
import { bind } from "astal"

export default function Battery() {
  const bat = AstalBattery.get_default()
  return new Widget.Icon({
    icon: bind(bat, "icon-name"),
    tooltipText: bind(bat, "percentage").as((p) => {
      return (p * 100).toString()
    })
  })

}
