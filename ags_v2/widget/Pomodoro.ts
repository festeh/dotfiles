import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"

export default function Pomodoro(focusing: Variable<string>) {
  return new Widget.Label({
    className: "pomodoro-widget",
    label: bind(focusing)
  })
}
