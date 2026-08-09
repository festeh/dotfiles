import { bind, timeout, Variable } from "astal";
import { Subscribable } from "astal/binding";
import { Astal, Gdk, Gtk, Widget } from "astal/gtk4";
import Notifd from "gi://AstalNotifd"
import Notification from "./Notification";

const TIMEOUT_DELAY = 30000 // 30 seconds
const RECOVERY_WINDOW = 5 * 60 * 1000 // 5 minutes

type CancellableTimer = {
  cancel: () => void
}

class NotificationHistory implements Subscribable {
  private map: Map<number, Gtk.Widget> = new Map()
  private timers: Map<number, CancellableTimer> = new Map()
  private subs: Variable<Array<Gtk.Widget>> = Variable([])

  private notifiy() {
    this.subs.set([...this.map.values()].reverse())
  }

  private cancelTimer(id: number) {
    this.timers.get(id)?.cancel()
    this.timers.delete(id)
  }

  private scheduleDismiss(notification: Notifd.Notification) {
    const { id } = notification
    const timer = timeout(TIMEOUT_DELAY, () => {
      // A replacement may have installed a newer timer for the same ID.
      if (this.timers.get(id) !== timer) return

      this.timers.delete(id)
      notification.dismiss()
    }) as CancellableTimer

    this.timers.set(id, timer)
  }

  private show(notification: Notifd.Notification) {
    const requiresManualDismiss = notification.urgency === Notifd.Urgency.CRITICAL
    this.cancelTimer(notification.id)

    const dismiss = () => {
      this.cancelTimer(notification.id)
      // Defer dismissal to avoid mutating the widget tree during a GTK event.
      timeout(1, () => notification.dismiss())
    }

    this.set(notification.id, Notification({
      notification,
      onDismiss: dismiss,

      onHoverLost: requiresManualDismiss ? undefined : dismiss,

      setup: () => {
        if (!requiresManualDismiss) {
          this.scheduleDismiss(notification)
        }
      }
    }))
  }

  constructor() {
    const notifd = Notifd.get_default()

    // Enforce our own timeout instead of sender's timeout
    notifd.ignoreTimeout = true

    notifd.connect("notified", (_, id) => {
      const notification = notifd.get_notification(id)!
      this.show(notification)
    })

    notifd.connect("resolved", (_, id) => {
      this.delete(id)
    })

    // Astal restores unresolved notifications from disk, but does not emit a
    // new "notified" signal for them. Recover only recent notifications so a
    // restart cannot flood the screen with a stale backlog.
    const restored = [...notifd.get_notifications()]
    timeout(1, () => {
      const now = Date.now()
      for (const notification of restored) {
        // A notification emitted again or resolved during startup has already
        // been handled by the live signal listeners above.
        if (this.map.has(notification.id) || !notifd.get_notification(notification.id)) continue

        const sentAt = notification.time > 1_000_000_000_000
          ? notification.time
          : notification.time * 1000
        const age = notification.time ? Math.max(0, now - sentAt) : Infinity

        if (notification.urgency === Notifd.Urgency.CRITICAL || age <= RECOVERY_WINDOW) {
          this.show(notification)
        } else {
          notification.dismiss()
        }
      }
    })
  }

  private set(key: number, value: Gtk.Widget) {
    // Just update the map, GTK will handle widget replacement
    this.map.set(key, value)
    this.notifiy()
  }

  private delete(key: number) {
    this.cancelTimer(key)

    const widget = this.map.get(key)
    if (!widget) {
      this.map.delete(key)
      this.notifiy()
      return
    }

    // Just remove from map and let notifiy() update the widget list
    // GTK will handle cleanup when widgets are removed from the box
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
    visible: bind(history).as(list => list.length > 0),
    exclusivity: Astal.Exclusivity.NORMAL,
    anchor: Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT,
  }, Widget.Box({
    vertical: true,
    spacing: 0,
  }, bind(history))

  )
}
