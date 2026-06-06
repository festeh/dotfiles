import { Gtk, Widget } from "astal/gtk4";
import { Variable, bind } from "astal";
import GLib from "gi://GLib"

function formatTime(date = new Date()) {
  return `${date.getHours().toString().padStart(2, "0")}:${date.getMinutes().toString().padStart(2, "0")}`
}

const time = Variable<string>(formatTime())

function scheduleMinuteTick() {
  const now = new Date()
  const delay = 60000 - (now.getSeconds() * 1000 + now.getMilliseconds())
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, delay, () => {
    time.set(formatTime())
    scheduleMinuteTick()
    return GLib.SOURCE_REMOVE
  })
}

scheduleMinuteTick()

export default function DateWidget(currentDate: Variable<Date>, calendarVisible: Variable<boolean>) {
  const button = Widget.Button({
    label: bind(time),
    // halign: Gtk.Align.CENTER,
    onClicked: () => {
      currentDate.set(new Date())
      const value = calendarVisible.get()
      calendarVisible.set(!value)
    }
  })
  return Widget.Box({
    css_classes: ["time-widget"],
    children: [button]
  })
}
