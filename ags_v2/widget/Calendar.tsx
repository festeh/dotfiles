import { App, Astal, Gtk } from "astal/gtk3"
import { Variable, bind } from "astal"

function makeRow(from, to) {
  const range = Array.from({ length: to - from + 1 }, (_, i) => i + from)
  return <box
    hexpand={true}
    css="color: blue; background-color: lightblue; padding: 1em;"
  >
    {range.map((label: number) => (
      <label label={label.toString()} xpad={2}/>
    ))}
  </box>
}

export default function Calendar(visible: Variable<boolean>) {
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
      {makeRow(1, 7)}
      {makeRow(8, 15)}
    </box>
    </window >
  )
}
