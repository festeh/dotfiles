import { App, Astal, Gdk, Gtk } from "astal/gtk3"
import { Variable, bind } from "astal"

const css = `
.calendar-row {
  margin: 0;
  padding: 0;
}

.calendar-cell {
  padding: 1em;
  border: 1px solid #6E6C7E;
  background-color: #302D41;
  color: #D9E0EE;
}

.calendar-cell.current-day {
  background-color: #F5C2E7;
  color: #1E1E2E;
  font-weight: bold;
}

.calendar-container {
  border: 1px solid #6E6C7E;
  background-color: #1E1E2E;
}

.month-label {
  font-weight: bold;
  font-size: 16px;
  margin-bottom: 10px;
  color: #F5C2E7;
}
`

const styleProvider = new Gtk.CssProvider()
styleProvider.load_from_data(css)
Gtk.StyleContext.add_provider_for_screen(
  Gdk.Screen.get_default(),
  styleProvider,
  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
)

function makeRow(from, to, currentDay) {
  const range = Array.from({ length: to - from + 1 }, (_, i) => i + from)
  return <box
    hexpand={true}
    halign={Gtk.Align.FILL}
    homogeneous={true}
    className="calendar-row"
  >
    {range.map((day: number) => (
      <label 
        className={`calendar-cell${day === currentDay ? ' current-day' : ''}`}
        label={day.toString()}
      />
    ))}
  </box>
}

export default function Calendar(visible: Variable<boolean>) {
  const currentDate = new Date()
  const currentDay = currentDate.getDate()
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
          {makeRow(1, 7, currentDay)}
          {makeRow(8, 14, currentDay)}
          {makeRow(15, 21, currentDay)}
          {makeRow(22, 28, currentDay)}
          {makeRow(29, 31, currentDay)}
        </box>
      </box>
    </window>
  )
}
