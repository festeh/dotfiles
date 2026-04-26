import { App, Astal, Gdk, Widget } from "astal/gtk4"
import { Variable } from "astal"
import Battery from "./Battery"
import MenuButton from "./MenuButton"
import IdleStatus from "./IdleStatus"
import LayoutStatus from "./LayoutStatus"
import Tray from "./Tray"
import HyprlandStatus from "./HyprlandStatus"
import TimeDate from "./TimeDate"
import Volume from "./Volume"
import Coach from "./Coach"


export default function Bar(monitor: Gdk.Monitor, calendarVisible: Variable<boolean>,
  currentDate: Variable<Date>,
  menuVisible: Variable<boolean>,
) {
  return Widget.Window(
    {
      className: "Bar",
      visible: true,
      gdkmonitor: monitor,
      exclusivity: Astal.Exclusivity.EXCLUSIVE,
      anchor: Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT,
      application: App
    },
    Widget.Box({
      className: "bar-container",
      children: [
        Widget.Box({
          hexpand: true,
          children: [
            HyprlandStatus(),
            Coach(),
          ]
        }),
        Widget.Box({
          children: [
            LayoutStatus(),
            IdleStatus(),
            MenuButton(menuVisible),
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
