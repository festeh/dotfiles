import { bind, timeout, Variable } from "astal";
import { Subscribable } from "astal/binding";
import { Astal, Gdk, Gtk, Widget } from "astal/gtk4";
import Notifd from "gi://AstalNotifd"
import Notification from "./Notification";

const TIMEOUT_DELAY = 30000 // 30 seconds

// List of app names that should not auto-dismiss
const PERSISTENT_APPS: string[] = [
  // Add app names here that should never auto-dismiss
  // Example: "Spotify", "Discord", etc.
]

class NotificationHistory implements Subscribable {
  private map: Map<number, Gtk.Widget> = new Map()
  private subs: Variable<Array<Gtk.Widget>> = Variable([])

  private notifiy() {
    this.subs.set([...this.map.values()].reverse())
  }

  constructor() {
    console.log("NotificationHistory: Starting initialization...")
    const notifd = Notifd.get_default()
    console.log("NotificationHistory: Notifd.get_default() completed")

    // Enforce our own timeout instead of sender's timeout
    notifd.ignoreTimeout = true
    console.log("NotificationHistory: Set ignoreTimeout=true")

    notifd.connect("notified", (_, id) => {
      console.log(`Notification received! ID: ${id}`)
      const notification = notifd.get_notification(id)!
      console.log(`Notification details: ${notification.summary}`)
      const isPersistent = PERSISTENT_APPS.includes(notification.appName || "")

      this.set(id, Notification({
        notification,

        // Defer dismissal to next event loop iteration to avoid GTK4 crash during event processing
        onHoverLost: () => {
          timeout(1, () => notification.dismiss())
        },

        setup: () => {
          if (!isPersistent) {
            timeout(TIMEOUT_DELAY, () => {
              notification.dismiss()
            })
          }
        }
      }))
    })

    notifd.connect("resolved", (_, id) => {
      this.delete(id)
    })
  }

  private set(key: number, value: Gtk.Widget) {
    // Just update the map, GTK will handle widget replacement
    this.map.set(key, value)
    this.notifiy()
  }

  private delete(key: number) {
    console.log(`Deleting notification ${key}`)
    const widget = this.map.get(key)
    if (!widget) {
      console.log(`Widget ${key} not found in map`)
      this.map.delete(key)
      this.notifiy()
      return
    }

    // Just remove from map and let notifiy() update the widget list
    // GTK will handle cleanup when widgets are removed from the box
    this.map.delete(key)
    console.log(`Removed notification ${key} from map`)
    this.notifiy()
  }

  // needed by the Subscribable interface
  get() {
    return this.subs.get()
  }

  // needed by the Subscribable interface
  subscribe(callback: (list: Array<Gtk.Widget>) => void) {
    return this.subs.subscribe(callback)
  }
}
export default function Notifications(monitor: Gdk.Monitor) {
  console.log("Notifications: Creating NotificationHistory...")
  const history = new NotificationHistory()
  console.log("Notifications: NotificationHistory created, creating window...")
  return Widget.Window({
    gdkmonitor: monitor,
    visible: bind(history).as(list => list.length > 0),
    exclusivity: Astal.Exclusivity.NORMAL,
    anchor: Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT,
  }, Widget.Box({
    vertical: true,
  }, bind(history))

  )
}
