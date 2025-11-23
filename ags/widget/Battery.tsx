import AstalBattery from "gi://AstalBattery?version=0.1"

import { Widget } from "astal/gtk4"
import { bind } from "astal"

export default function Battery() {
  const bat = AstalBattery.get_default()
  return Widget.Box({
    css_classes: bind(bat, "percentage").as((p) =>
      p < 0.20 ? ["battery-widget", "battery-low"] : ["battery-widget"]
    ),
    children: [
      Widget.Image({
        iconName: bind(bat, "icon-name"),
      }),
      Widget.Label({
        label: bind(bat, "percentage").as((p) => {
          return `${Math.round(p * 100)}%`
        }),
      }),
    ],
  })
}
