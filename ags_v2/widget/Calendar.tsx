import { App, Astal, Gtk } from "astal/gtk3"
import { Variable, bind } from "astal"

function makeRow(from, to) {
  const range = Array.from({ length: to - from + 1 }, (_, i) => i + from)
  return <grid
    hexpand={true}
    halign={Gtk.Align.FILL}
    column_homogeneous={true}
    row_homogeneous={true}
    column_spacing={0}
    row_spacing={0}
  >
    {range.map((label: number) => (
      <label 
        css="padding: 1em; border: 1px solid black; background-color: lightblue; color: blue;"
        label={label.toString()}
      />
    ))}
  </grid>
}

export default function Calendar(visible: Variable<boolean>) {
  const currentDate = new Date()
  const currentMonth = currentDate.getMonth()
  const monthName = currentDate.toLocaleString('default', { month: 'long' })
  return (
    <window
      className="Calendar"
      visible={bind(visible)}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
      application={App}>
      <box
        css="padding: 1em;"
        spacing={5}
        valign={Gtk.Align.FILL}
        vertical={true}
      >
        <label css="font-weight: bold; font-size: 16px; margin-bottom: 10px;" label={monthName} />
        <box css="border: 1px solid black;">
          {makeRow(1, 7)}
          {makeRow(8, 14)}
          {makeRow(15, 21)}
          {makeRow(22, 28)}
          {makeRow(29, 31)}
        </box>
      </box>
    </window>
  )
}
