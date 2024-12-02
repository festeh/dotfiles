import { bind, timeout, Variable } from "astal";
import { Subscribable } from "astal/binding";
import { Astal, Gtk, Widget } from "astal/gtk3";
import Notifd from "gi://AstalNotifd"
import  Notification  from "./Notification";

const TIMEOUT_DELAY = 5000

class NotificationHistory implements Subscribable {
  private map: Map<number, Gtk.Widget> = new Map()
  private subs: Variable<Array<Gtk.Widget>> = Variable([])

  private notifiy() {
    this.subs.set([...this.map.values()].reverse())
  }

  constructor() {
    console.log("notifications")
    const notifd = Notifd.get_default()

    /**
     * uncomment this if you want to
     * ignore timeout by senders and enforce our own timeout
     * note that if the notification has any actions
     * they might not work, since the sender already treats them as resolved
     */
    // notifd.ignoreTimeout = true

    notifd.connect("notified", (_, id) => {
      this.set(id, Notification({
        notification: notifd.get_notification(id)!,

        onHoverLost: () => this.delete(id),

        setup: () => timeout(TIMEOUT_DELAY, () => {
          // this.delete(id)
        })
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
export default function Notifications() {
  const history = new NotificationHistory()
  return new Widget.Window({
    exclusivity: Astal.Exclusivity.EXCLUSIVE,
    anchor: Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT,
  }, new Widget.Box({

  }, bind(history))

  )
}
