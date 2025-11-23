import { Widget } from "astal/gtk4"
import { Variable, bind } from "astal"

export default function Pomodoro(pomodoro: Variable<string>) {
  return Widget.Label({
    className: "pomodoro-widget",
    label: bind(pomodoro)
  })
}
