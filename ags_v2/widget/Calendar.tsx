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

.weekday-header {
  font-weight: bold;
  color: #89DCEB;
  padding: 0.5em;
}
`

const styleProvider = new Gtk.CssProvider()
styleProvider.load_from_data(css)
Gtk.StyleContext.add_provider_for_screen(
  Gdk.Screen.get_default(),
  styleProvider,
  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
)

function makeWeekdayHeader() {
  const weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
  return <box
    hexpand={true}
    halign={Gtk.Align.FILL}
    homogeneous={true}
    className="calendar-row"
  >
    {weekdays.map((day: string) => (
      <label 
        className="weekday-header"
        label={day}
      />
    ))}
  </box>
}

function generateCalendarDays(year: number, month: number, currentDay: number) {
  const firstDay = new Date(year, month, 1).getDay()
  const daysInMonth = new Date(year, month + 1, 0).getDate()
  const days = Array(firstDay === 0 ? 6 : firstDay - 1).fill(null)
    .concat(Array.from({ length: daysInMonth }, (_, i) => i + 1))

  const rows = []
  for (let i = 0; i < days.length; i += 7) {
    const weekDays = days.slice(i, i + 7)
    rows.push(
      <box
        hexpand={true}
        halign={Gtk.Align.FILL}
        homogeneous={true}
        className="calendar-row"
      >
        {weekDays.map((day: number | null) => (
          <label 
            className={`calendar-cell${day === currentDay ? ' current-day' : ''}`}
            label={day ? day.toString() : ''}
          />
        ))}
      </box>
    )
  }
  return rows
}

function makeWeekdayHeader() {
  const weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
  return <box
    hexpand={true}
    halign={Gtk.Align.FILL}
    homogeneous={true}
    className="calendar-row"
  >
    {weekdays.map((day: string) => (
      <label 
        className="weekday-header"
        label={day}
      />
    ))}
  </box>
}

export default function Calendar(visible: Variable<boolean>) {
  const currentDate = new Date()
  const currentDay = currentDate.getDate()
  const currentMonth = currentDate.getMonth()
  const currentYear = currentDate.getFullYear()
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
          {makeWeekdayHeader()}
          {generateCalendarDays(currentYear, currentMonth, currentDay)}
        </box>
      </box>
    </window>
  )
}
