import { App, Astal, Gtk, Widget } from "astal/gtk3"
import { Variable } from "astal"
import Battery from "./Battery"
import Idle from "./Idle"
import Tray from "./Tray"
import Hyprland from "gi://AstalHyprland"
import HyprlandStatus from "./HyprlandStatus"
import TimeDate from "./TimeDate"
import Volume from "./Volume"
import Focusing from "./Focusing"
import Pomodoro from "./Pomodoro"

const hypr = Hyprland.get_default()
const monitors = hypr.get_monitors()
let id = 0


export default function Bar(calendarVisible: Variable<boolean>, 
                            currentDate: Variable<Date>,
                            focusing: Variable<string>,
                            pomodoro: Variable<string>,
                           ) {
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
          children: [
            HyprlandStatus(),
            Focusing(focusing),
            Pomodoro(pomodoro)
          ]
        }),
        new Widget.Box({
          children: [
            Idle(),
            Volume(),
            Battery(),
            TimeDate(currentDate, calendarVisible),
            Tray()
          ]
        })
      ]
    })
  )
}
