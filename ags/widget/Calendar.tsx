import { App, Astal, Gdk, Gtk } from "astal/gtk4"
import { Variable, bind } from "astal"

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
  const today = new Date()
  const todayDay = today.getDate()
  const todayMonth = today.getMonth()
  const todayYear = today.getFullYear()

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
    const viewedMonth = currentDate.get().getMonth()
    const viewedYear = currentDate.get().getFullYear()
    const isCurrentMonth = viewedMonth === todayMonth && viewedYear === todayYear

    const r = []
    for (let i = 0; i < d.length; i += 7) {
      const weekDays = d.slice(i, i + 7)
      r.push(
        <box
          hexpand={true}
          halign={Gtk.Align.FILL}
          homogeneous={true}
          cssClasses={["calendar-row"]}
        >
          {weekDays.map((day: number | null) => (
            <label
              label={day ? day.toString() : ''}
              cssClasses={isCurrentMonth && day === todayDay ? ['calendar-cell', 'current-day'] : ['calendar-cell']}
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
    cssClasses={["calendar-row"]}
  >
    {weekdays.map((day: string) => (
      <label
        cssClasses={["weekday-header"]}
        label={day}
      />
    ))}
  </box>
}

export default function Calendar(monitor: Gdk.Monitor, visible: Variable<boolean>, currentDate: Variable<Date>) {
  const monthName = bind(currentDate).as((date: Date) => date.toLocaleString('default', { month: 'long', year: 'numeric' }))

  const previousMonth = () => {
    const current = currentDate.get()
    const newDate = new Date(current.getFullYear(), current.getMonth() - 1, 1)
    currentDate.set(newDate)
  }

  const nextMonth = () => {
    const current = currentDate.get()
    const newDate = new Date(current.getFullYear(), current.getMonth() + 1, 1)
    currentDate.set(newDate)
  }

  return (
    <window
      gdkmonitor={monitor}
      cssClasses={["Calendar"]}
      visible={bind(visible)}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
      application={App}>
      <box
        cssClasses={["calendar-widget"]}
        spacing={5}
        valign={Gtk.Align.FILL}
        orientation={Gtk.Orientation.VERTICAL}
      >
        <box cssClasses={["calendar-header"]} spacing={10}>
          <button cssClasses={["calendar-nav-button"]} onClicked={previousMonth}>
            <label label="◀" />
          </button>
          <label cssClasses={["month-label"]} label={monthName} hexpand={true} />
          <button cssClasses={["calendar-nav-button"]} onClicked={nextMonth}>
            <label label="▶" />
          </button>
        </box>
        <box cssClasses={["calendar-container"]} orientation={Gtk.Orientation.VERTICAL}>
          {makeWeekdayHeader()}
          {generateCalendarDays(currentDate)}
        </box>
      </box>
    </window>
  )
}
