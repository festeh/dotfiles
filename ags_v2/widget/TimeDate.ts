import { Gtk, Widget } from "astal/gtk3";
import { Variable, bind } from "astal";


const time = Variable<string>("").poll(1000, "date +%H:%M")

export default function DateWidget(currentDate, calendarVisible) {
  return new Widget.Button({
    label: bind(time),
    // halign: Gtk.Align.CENTER,
    onClicked: () => {
      currentDate.set(new Date())
      const value = calendarVisible.get()
      calendarVisible.set(!value)
    }
  })
}
