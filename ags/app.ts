import { App, Gdk, Astal, Widget } from "astal/gtk4"
import style from "inline:./style.css"
import Bar from "./widget/Bar"
import Calendar from "./widget/Calendar"
import Notifications from "./widget/Notifications"
import Menu, { toggleRecording } from "./widget/Menu"
import { Variable } from "astal"
import "./service/WorkspaceNaming"

const calendarVisible = Variable(false)
const currentDate = Variable(new Date())
const menuVisible = Variable(false)


const display = Gdk.Display.get_default()!

function getBestMonitor() {
  let monitor: Gdk.Monitor | null = null
  let width = -1
  const monitors = display.get_monitors()
  for (let idx = 0; idx < monitors.get_n_items(); idx++) {
    const m = monitors.get_item(idx) as Gdk.Monitor;
    if (m.get_geometry().width > width) {
      width = m.get_geometry().width
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
  requestHandler(request: string, response: (res: string) => void) {
    if (request === "toggle-recording") {
      menuVisible.set(true)
      toggleRecording()
      response("ok")
    } else {
      response(`Unknown command: ${request}`)
    }
  },
  main() {
    Bar(monitor, calendarVisible, currentDate, menuVisible)
    Notifications(monitor)
    Calendar(monitor, calendarVisible, currentDate)
    Menu(monitor, menuVisible)

    // Note: GTK4 monitor events work differently
    // TODO: Implement monitor hotplug using Gdk.Display signals if needed
  },
})
