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
    const notifd = Notifd.get_default()

    // Enforce our own timeout instead of sender's timeout
    notifd.ignoreTimeout = true

    notifd.connect("notified", (_, id) => {
      const notification = notifd.get_notification(id)!
      const isPersistent = PERSISTENT_APPS.includes(notification.appName || "")

      this.set(id, Notification({
        notification,

        onHoverLost: () => this.delete(id),

        setup: () => {
          // Only auto-dismiss if not in persistent apps list
          if (!isPersistent) {
            timeout(TIMEOUT_DELAY, () => {
              this.delete(id)
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
    this.map.get(key)?.destroy()
    this.map.set(key, value)
    this.notifiy()
  }

  private delete(key: number) {
    this.map.get(key)?.destroy()
    this.map.delete(key)
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
  const history = new NotificationHistory()
  return Widget.Window({
    gdkmonitor: monitor,
    exclusivity: Astal.Exclusivity.EXCLUSIVE,
    anchor: Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT,
  }, Widget.Box({

  }, bind(history))

  )
}
