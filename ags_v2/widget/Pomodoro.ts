import { Widget } from "astal/gtk3"

export default function Pomodoro() {
  return new Widget.Label(
    { label: "Pomodoro" }
  )
}
