import { App, Astal, Gtk } from "astal/gtk3"
import { Variable, bind } from "astal"

function makeRow(from, to) {
  const range = Array.from({ length: to - from + 1 }, (_, i) => i + from)
  return <box
    hexpand={true}
    halign={Gtk.Align.FILL}

    css="color: blue; background-color: lightblue; padding: 2em;"
  >
    {range.map((label: number) => (
      <label css="padding: 1em; border: 1px solid black" label={label.toString()} />
    ))}
  </box>
}

export default function Calendar(visible: Variable<boolean>) {
  const currentDate = new Date()
  const currentMonth = currentDate.getMonth()
  const monthName = currentDate.toLocaleString('default', { month: 'long' })
  return (
    <window
      className="Calendar"

      visible={bind(visible)}
      // monitor={monitor}
      // exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={Astal.WindowAnchor.TOP
        // | Astal.WindowAnchor.LEFT
        | Astal.WindowAnchor.RIGHT
      }
      application={App}>
      <box
        css="padding: 1em;"
        spacing={5}
        valign={Gtk.Align.FILL}
        vertical={true}
      >
        {monthName}
        {makeRow(1, 7)}
        {makeRow(8, 15)}
      </box>
    </window >
  )
}
