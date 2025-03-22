import { Widget } from "astal/gtk3"
import { Variable, bind } from "astal"
import GLib from "gi://GLib"

async function loadCoachUrl() {
  // Wait for 1 second
  await new Promise(resolve => GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
    resolve(true);
    return GLib.SOURCE_REMOVE;
  }));
  
  const coachUrl = GLib.getenv("COACH_URL")
  console.log("COACH_URL:", coachUrl)
}

export default function Coach() {
  // Start the async loading process
  loadCoachUrl();
  
  return new Widget.Label({
    className: "focusing-widget",
    label: "SOSAT"
  })
}
