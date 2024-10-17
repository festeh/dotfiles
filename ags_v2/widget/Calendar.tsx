import { App, Astal, Gtk } from "astal/gtk3"


export default function Calendar() {
  return (
    <window
      className="Calendar"
      // monitor={monitor}
      // exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={Astal.WindowAnchor.TOP
        // | Astal.WindowAnchor.LEFT
        | Astal.WindowAnchor.RIGHT
      }
      application={App}>
       <box>
          1 2 3 4 5
          6 4 3 2 1
       </box>
    </window>
  )
}
