import { Gtk, Widget } from "astal/gtk4";
import { Variable, bind } from "astal";


const time = Variable<string>("").poll(1000, "date +%H:%M")

export default function DateWidget(currentDate, calendarVisible) {
  const button = Widget.Button({
    className: "time-button",
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
