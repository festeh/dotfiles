import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"
import GLib from "gi://GLib"

export default function Coach() {
  const coachUrl = GLib.getenv("COACH_URL")
  console.log("COACH_URL:", coachUrl)
  
  return new Widget.Label({
    className: "focusing-widget",
    label: "SOSAT"
  })
}
