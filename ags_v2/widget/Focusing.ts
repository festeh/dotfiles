import { Widget } from "astal/gtk3"

export default function Focusing() {
  return new Widget.Label({
    className: "focusing-widget",
    label: "Not focusing"
  })
}
