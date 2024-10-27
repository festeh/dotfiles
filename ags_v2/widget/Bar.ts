import { App, Astal, Gtk, Widget } from "astal/gtk3"
import { Variable } from "astal"
import Battery from "./Battery"
import Tray from "./Tray"
import Hyprland from "gi://AstalHyprland"
import HyprlandStatus from "./HyprlandStatus"
import TimeDate from "./TimeDate"

const hypr = Hyprland.get_default()
const monitors = hypr.get_monitors()
let id = 0


export default function Bar(calendarVisible: Variable<boolean>, currentDate: Variable<Date>) {
  return new Widget.Window(
    {
      className: "Bar",
      exclusivity: Astal.Exclusivity.EXCLUSIVE,
      anchor: Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT,
      application: App
    },
    new Widget.Box({
      className: "bar-container",
      children: [
        new Widget.Box({
          hexpand: true,
          halign: "start",
          children: [HyprlandStatus()]
        }),
        new Widget.Box({
          halign: "end",
          children: [Battery(), TimeDate(currentDate, calendarVisible), Tray()]
        })
      ]
    })
  )
}