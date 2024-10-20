import { App, Astal, Gtk } from "astal/gtk3"
import { Variable } from "astal"
import Hyprland from "gi://AstalHyprland"
const time = Variable<string>("").poll(1000, "date +%H:%M")

const hypr = Hyprland.get_default()
const monitors = hypr.get_monitors()
let id = 0


export default function Bar(calendarVisible: Variable<boolean>) {
    return <window
        className="Bar"
        // monitor={monitor}
        exclusivity={Astal.Exclusivity.EXCLUSIVE}
        anchor={Astal.WindowAnchor.TOP
            | Astal.WindowAnchor.LEFT
            | Astal.WindowAnchor.RIGHT}
        application={App}>
        <centerbox>
            <button
                onClicked="echo hello"
                halign={Gtk.Align.CENTER} >
                Welcome to AGS!
            </button>
            <box />
            <button
                onClick={() => {
                  const value = calendarVisible.get()
                  calendarVisible.set(!value)
                }}
                halign={Gtk.Align.CENTER} >
                <label label={time()} />
            </button>
        </centerbox>
    </window>
}
