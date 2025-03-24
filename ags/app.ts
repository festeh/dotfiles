import { App, Gdk } from "astal/gtk3"
import style from "inline:./style.css"
import Bar from "./widget/Bar"
import Calendar from "./widget/Calendar"
import Notifications from "./widget/Notifications"
import { Variable } from "astal"

const calendarVisible = Variable(false)
const currentDate = Variable(new Date())


const display = Gdk.Display.get_default()!

function getBestMonitor() {
  let monitor: Gdk.Monitor | null = null
  let width = -1
  for (let idx = 0; idx < display.get_n_monitors(); idx++) {
    const m = display.get_monitor(idx)!;
    if (m.get_width_mm() > width) {
      width = m.get_width_mm()
      monitor = m
    }
  }
  return monitor
}

let monitor = getBestMonitor()
if (monitor === null) {
  console.error("No monitor found")
  throw new Error("No monitor found")
}

function initWidgets(monitor: Gdk.Monitor) {
  return [
    Bar(monitor, calendarVisible, currentDate),
    Calendar(monitor, calendarVisible, currentDate),
    Notifications(monitor)
  ]
}

App.start({
  css: style,
  main() {
    let widgets = initWidgets(monitor)

    App.connect("monitor-added", (_, gdkmonitor) => {
      if (getBestMonitor() === gdkmonitor) {
        widgets.forEach(w => w.destroy())
        widgets = initWidgets(gdkmonitor)
      }
    })

    App.connect("monitor-removed", (_, _gdkmonitor) => {
      widgets.forEach(w => w.destroy())
      const mon = getBestMonitor()
      if (mon !== null) {
        widgets = initWidgets(mon)
      }
    })
  },
})
