import { App, Astal, Gdk, Gtk } from "astal/gtk4"
import { Variable, bind } from "astal"

const css = `
.calendar-widget {
  background-color: #1E1E2E;
  padding: 10px;
  margin-right: 10px;
  border-radius: 10px;
}

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
styleProvider.load_from_string(css)
Gtk.StyleContext.add_provider_for_display(
  Gdk.Display.get_default(),
  styleProvider,
  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
)

// function makeWeekdayHeader() {
//   const weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
//   return <box
//     hexpand={true}
//     halign={Gtk.Align.FILL}
//     homogeneous={true}
//     className="calendar-row"
//   >
//     {weekdays.map((day: string) => (
//       <label 
//         className="weekday-header"
//         label={day}
//       />
//     ))}
//   </box>
// }

function generateCalendarDays(currentDate: Variable<Date>) {
  const currentDay = bind(currentDate).as((date: Date) => date.getDate())
  const month = bind(currentDate).as((date: Date) => date.getMonth()).get()
  const year = bind(currentDate).as((date: Date) => date.getFullYear()).get()
  const firstDay = bind(currentDate).as((date: Date) => {
    const year = date.getFullYear()
    const month = date.getMonth()
    return new Date(year, month, 1).getDay()
  })

  const daysInMonth = bind(currentDate).as((date: Date) => {
    const year = date.getFullYear()
    const month = date.getMonth()
    return new Date(year, month + 1, 0).getDate()
  })

  const days = Variable.derive(
    [firstDay, daysInMonth],
    (firstDay, daysInMonth) => {
      const d = Array(firstDay === 0 ? 6 : firstDay - 1).fill(null)
        .concat(Array.from({ length: daysInMonth }, (_, i) => i + 1))
      // Pad the array to ensure it's divisible by 7
      while (d.length % 7 !== 0) {
        d.push(null)
      }
      return d
    }
  )
  const rows = bind(days).as((d: number[]) => {
    const r = []
    for (let i = 0; i < d.length; i += 7) {
      const weekDays = d.slice(i, i + 7)
      r.push(
        <box
          hexpand={true}
          halign={Gtk.Align.FILL}
          homogeneous={true}
          className="calendar-row"
        >
          {weekDays.map((day: number | null) => (
            <label
              label={day ? day.toString() : ''}
              className={bind(currentDay).as((cDay: number) => cDay === day ? 'calendar-cell current-day' : 'calendar-cell')}
            />
          ))}
        </box>
      )
    }
    return r
  })

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

export default function Calendar(monitor: Gdk.Monitor, visible: Variable<boolean>, currentDate: Variable<Date>) {
  const monthName = bind(currentDate).as((date: Date) => date.toLocaleString('default', { month: 'long' }))
  return (
    <window
      gdkmonitor={monitor}
      className="Calendar"
      visible={bind(visible)}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
      application={App}>
      <box
        className="calendar-widget"
        spacing={5}
        valign={Gtk.Align.FILL}
        orientation={Gtk.Orientation.VERTICAL}
      >
        <label className="month-label" label={monthName} />
        <box className="calendar-container" orientation={Gtk.Orientation.VERTICAL}>
          {makeWeekdayHeader()}
          {generateCalendarDays(currentDate)}
        </box>
      </box>
    </window>
  )
}
