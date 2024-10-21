import { App, Astal, Gtk } from "astal/gtk3"
import { Variable, bind } from "astal"

const css = `
.calendar-row {
  margin: 0;
  padding: 0;
}

.calendar-cell {
  padding: 1em;
  border: 1px solid black;
  background-color: lightblue;
  color: blue;
}

.calendar-container {
  border: 1px solid black;
}

.month-label {
  font-weight: bold;
  font-size: 16px;
  margin-bottom: 10px;
}
`

const styleProvider = new Gtk.CssProvider()
styleProvider.load_from_data(css)
Gtk.StyleContext.add_provider_for_screen(
  Gdk.Screen.get_default(),
  styleProvider,
  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
)

function makeRow(from, to) {
  const range = Array.from({ length: to - from + 1 }, (_, i) => i + from)
  return <box
    hexpand={true}
    halign={Gtk.Align.FILL}
    homogeneous={true}
    className="calendar-row"
  >
    {range.map((label: number) => (
      <label 
        className="calendar-cell"
        label={label.toString()}
      />
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
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
      application={App}>
      <box
        spacing={5}
        valign={Gtk.Align.FILL}
        margin={10}
        orientation={Gtk.Orientation.VERTICAL}
      >
        <label className="month-label" label={monthName} />
        <box className="calendar-container" orientation={Gtk.Orientation.VERTICAL}>
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
