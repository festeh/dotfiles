import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"

export default function Coach() {
  return new Widget.Label({
    className: "focusing-widget",
    label: "SOSAT"
  })
}
