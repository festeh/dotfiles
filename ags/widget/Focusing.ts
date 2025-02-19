import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"

export default function Focusing(focusing: Variable<string>) {
  return new Widget.Label({
    className: "focusing-widget",
    label: bind(focusing)
  })
}
