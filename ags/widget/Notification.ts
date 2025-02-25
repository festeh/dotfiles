import { GLib } from "astal"
import { Astal, Gtk, Widget } from "astal/gtk3"
import { EventBox } from "astal/gtk3/widget"
import Notifd from "gi://AstalNotifd"
// CSS styles are loaded from style.css

const time = (time: number, format = "%H:%M") => GLib.DateTime
  .new_from_unix_local(time)
  .format(format)!

const fileExists = (path: string) =>
  GLib.file_test(path, GLib.FileTest.EXISTS)

const isIcon = (icon: string) =>
  !!Astal.Icon.lookup_icon(icon)

type Props = {
  setup(self: EventBox): void
  onHoverLost(self: EventBox): void
  notification: Notifd.Notification
}

function headerBox(n: Notifd.Notification): Widget.Box {
  let children = []
  if (n.appIcon || n.desktopEntry) {
    children.push(new Widget.Icon({
      className: "app-icon",
      icon: n.appIcon || n.desktopEntry,
      visible: Boolean(n.appIcon || n.desktopEntry)
    }))
  }
  children.push(new Widget.Label({
    className: "app-name",
    halign: Gtk.Align.START,
    truncate: true,
    label: n.appName || "Unknown"
  }))
  children.push(new Widget.Label({
    className: "time",
    halign: Gtk.Align.END,
    hexpand: true,
    label: time(n.time)
  }))
  children.push(
    new Widget.Button({
      className: "dismiss-button",
      onClicked: () => n.dismiss()
    }), new Widget.Icon({
      icon: "window-close-symbolic"
    })
  )
  return new Widget.Box({}, ...children)
}

function contentBox(n: Notifd.Notification): Widget.Box {
  let children = []
  if (n.image && fileExists(n.image)) {
    children.push(new Widget.Box({
      valign: Gtk.Align.START,
      className: "image",
      css: `background-image: url('${n.image}')`
    }))
  }
  if (n.image && isIcon(n.image)) {
    children.push(new Widget.Box({
      expand: false,
      valign: Gtk.Align.START,
      className: "icon-image",
    }, new Widget.Icon({
      icon: n.image,
      expand: true,
      halign: Gtk.Align.CENTER,
      valign: Gtk.Align.CENTER,
    })))
  }
  const contentBox = new Widget.Box({
    vertical: true,
  }, new Widget.Label({
    className: "summary",
    halign: Gtk.Align.START,
    xalign: 0,
    label: n.summary,
    truncate: true,
  }))
  if (n.body) {
    contentBox.add(new Widget.Label({
      className: "body",
      wrap: true,
      useMarkup: true,
      halign: Gtk.Align.START,
      xalign: 0,
      label: n.body,
      justifyFill: true
    }))
  }
  children.push(contentBox)
  return new Widget.Box({}, ...children)
}

function getActions(n: Notifd.Notification): Widget.Button[] {
  return n.get_actions().map(({ label, id }) => new Widget.Button({
    hexpand: true,
    className: "action-button",
    label,
    onClicked: () => n.invoke(id)
  }))
}

export default function Notification(props: Props) {
  const { notification: n, onHoverLost, setup } = props
  const eb = new EventBox({
    setup,
    onHoverLost,
    className: "notification-widget",
  }, new Widget.Box({ vertical: true },
    headerBox(n),
    new Gtk.Separator({ visible: true }),
    contentBox(n)
  ))
  if (n.get_actions().length > 0) {
    const actions = getActions(n)
    for (let i = 0; i < actions.length; i++) {
      eb.add(actions[i])
    }
  }
  return eb
}
