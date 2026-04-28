import { App, Astal, Gdk, Widget } from "astal/gtk4"
import { Variable } from "astal"
import Gtk from "gi://Gtk?version=4.0"
import Battery from "./Battery"
import MenuButton from "./MenuButton"
import IdleStatus from "./IdleStatus"
import LayoutStatus from "./LayoutStatus"
import Tray from "./Tray"
import HyprlandStatus from "./HyprlandStatus"
import TimeDate from "./TimeDate"
import Volume from "./Volume"


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
    (() => {
      const leftScroll = new Gtk.ScrolledWindow()
      leftScroll.set_policy(Gtk.PolicyType.EXTERNAL, Gtk.PolicyType.NEVER)
      leftScroll.set_propagate_natural_width(false)
      leftScroll.set_propagate_natural_height(true)
      leftScroll.set_hexpand(true)
      leftScroll.set_child(Widget.Box({
        children: [
          HyprlandStatus(),
        ],
      }))

      return Widget.Box({
        className: "bar-container",
        children: [
          leftScroll,
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
    })()
  )
}
