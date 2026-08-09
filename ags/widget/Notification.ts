import { Gdk, Gtk, Widget } from "astal/gtk4"
import GdkPixbuf from "gi://GdkPixbuf"
import Gio from "gi://Gio"
import GLib from "gi://GLib"
import Pango from "gi://Pango"
import Notifd from "gi://AstalNotifd"

type NotificationProps = {
  notification: Notifd.Notification
  onDismiss?: () => void
  onHoverLost?: () => void
  setup?: () => void
}

type DesktopIdentity = {
  icon: Gio.Icon | null
  name: string | null
}

const desktopIdentityCache = new Map<string, DesktopIdentity>()

function urgencyClass(urgency: Notifd.Urgency) {
  switch (urgency) {
    case Notifd.Urgency.LOW:
      return "notification-low"
    case Notifd.Urgency.CRITICAL:
      return "notification-critical"
    default:
      return "notification-normal"
  }
}

function notificationDate(unixTime: number) {
  if (!unixTime) return new Date()

  // Astal currently reports seconds, but accepting milliseconds here keeps the
  // timestamp resilient to senders which provide an already-converted value.
  return new Date(unixTime > 1_000_000_000_000 ? unixTime : unixTime * 1000)
}

function relativeTime(date: Date) {
  const elapsedSeconds = Math.max(0, Math.floor((Date.now() - date.getTime()) / 1000))

  if (elapsedSeconds < 60) return "now"
  if (elapsedSeconds < 3600) return `${Math.floor(elapsedSeconds / 60)}m`
  if (elapsedSeconds < 86400) return `${Math.floor(elapsedSeconds / 3600)}h`
  if (elapsedSeconds < 604800) return `${Math.floor(elapsedSeconds / 86400)}d`

  return date.toLocaleDateString(undefined, { month: "short", day: "numeric" })
}

function localPath(path: string) {
  return path.startsWith("~/") ? `${GLib.get_home_dir()}${path.slice(1)}` : path
}

function isLocalPath(path: string | null | undefined) {
  return Boolean(path?.trim()) &&
    (path!.startsWith("/") || path!.startsWith("~/")) &&
    !path!.includes("..")
}

function desktopIdentity(desktopEntry: string): DesktopIdentity {
  const entry = desktopEntry.trim()
  if (!entry) return { icon: null, name: null }

  const cached = desktopIdentityCache.get(entry)
  if (cached) return cached

  const desktopId = entry.endsWith(".desktop") ? entry : `${entry}.desktop`
  const app = Gio.AppInfo.get_all().find(info =>
    info.get_id()?.toLocaleLowerCase() === desktopId.toLocaleLowerCase()
  )
  const identity = {
    icon: app?.get_icon() || null,
    name: app?.get_display_name() || null,
  }

  desktopIdentityCache.set(entry, identity)
  return identity
}

function appIcon(notification: Notifd.Notification, desktopIcon: Gio.Icon | null): Gtk.Widget {
  if (isLocalPath(notification.appIcon)) {
    try {
      const pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(localPath(notification.appIcon), 28, 28, true)
      const picture = Gtk.Picture.new_for_pixbuf(pixbuf)
      picture.add_css_class("notification-icon")
      picture.set_size_request(28, 28)
      picture.set_content_fit(Gtk.ContentFit.CONTAIN)
      return picture
    } catch (error) {
      console.warn(`Could not load notification icon: ${error}`)
    }
  }

  const iconName = notification.appIcon?.trim()
  const display = Gdk.Display.get_default()
  if (iconName && !isLocalPath(iconName) &&
      (!display || Gtk.IconTheme.get_for_display(display).has_icon(iconName))) {
    return Widget.Image({
      css_classes: ["notification-icon"],
      iconName,
      pixelSize: 24,
      widthRequest: 28,
      heightRequest: 28,
    })
  }

  if (desktopIcon) {
    return Widget.Image({
      css_classes: ["notification-icon"],
      gicon: desktopIcon,
      pixelSize: 24,
      widthRequest: 28,
      heightRequest: 28,
    })
  }

  return Widget.Image({
    css_classes: ["notification-icon"],
    iconName: "dialog-information-symbolic",
    pixelSize: 24,
    widthRequest: 28,
    heightRequest: 28,
  })
}

function notificationImage(notification: Notifd.Notification): Gtk.Widget | null {
  if (!isLocalPath(notification.image)) return null

  try {
    // Scale the source before handing it to Gtk.Picture so a very large image
    // cannot dictate the natural width of the notification window.
    const pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(localPath(notification.image), 350, 140, true)
    const picture = Gtk.Picture.new_for_pixbuf(pixbuf)
    picture.add_css_class("notification-image")
    picture.set_hexpand(true)
    picture.set_vexpand(true)
    picture.set_can_shrink(true)
    picture.set_content_fit(Gtk.ContentFit.CONTAIN)
    picture.set_alternative_text(notification.summary || `${notification.appName} notification image`)

    // Gtk.Picture otherwise requests enough height to preserve a square
    // image's natural ratio. The frame makes the media area a stable banner.
    const frame = Gtk.AspectFrame.new(0.5, 0.5, 2.5, false)
    frame.add_css_class("notification-image-frame")
    frame.set_hexpand(true)
    frame.set_overflow(Gtk.Overflow.HIDDEN)
    frame.set_child(picture)
    return frame
  } catch (error) {
    console.warn(`Could not load notification image: ${error}`)
    return null
  }
}

function actionButton(notification: Notifd.Notification, action: Notifd.Action) {
  const display = Gdk.Display.get_default()
  const iconTheme = display ? Gtk.IconTheme.get_for_display(display) : null
  const iconName = notification.actionIcons && iconTheme?.has_icon(action.id)
    ? action.id
    : null

  return Widget.Button({
    css_classes: [
      "notification-action",
      ...(action.id === "default" ? ["notification-action-primary"] : []),
      ...(iconName ? ["notification-action-with-icon"] : []),
    ],
    tooltipText: iconName ? action.label : undefined,
    canShrink: true,
    hexpand: true,
    onClicked: () => notification.invoke(action.id),
    ...(iconName ? {
      child: Widget.Box({
        spacing: 6,
        halign: Gtk.Align.CENTER,
        children: [
          Widget.Image({
            css_classes: ["notification-action-icon"],
            iconName,
            pixelSize: 15,
          }),
          Widget.Label({
            label: action.label,
            ellipsize: Pango.EllipsizeMode.END,
            maxWidthChars: 24,
          }),
        ],
      }),
    } : {
      label: action.label,
    }),
  })
}

function progressValue(notification: Notifd.Notification): number | null {
  const hint = notification.get_hint("value")
  if (!hint) return null

  try {
    const value = hint.deepUnpack<unknown>()
    if (typeof value !== "number" || !Number.isFinite(value)) return null
    return Math.max(0, Math.min(100, Math.round(value)))
  } catch (error) {
    console.warn(`Could not read notification progress: ${error}`)
    return null
  }
}

export default function Notification({ notification, onDismiss, onHoverLost, setup }: NotificationProps): Gtk.Widget {
  const sentAt = notificationDate(notification.time)
  const identity = desktopIdentity(notification.desktopEntry)
  const appName = notification.appName?.trim() || identity.name || "Notification"
  const image = notificationImage(notification)
  const progress = progressValue(notification)
  const hasBody = Boolean(notification.body?.trim())
  const defaultAction = notification.actions?.find(action => action.id === "default")
  const validActions = notification.actions?.filter(action =>
    Boolean(action.label?.trim()) && Boolean(action.id)
  ) || []

  const box = Widget.Box({
    css_classes: ["notification", urgencyClass(notification.urgency)],
    vertical: true,
    halign: Gtk.Align.END,
    children: [
      Widget.Box({
        css_classes: ["notification-header"],
        spacing: 8,
        children: [
          appIcon(notification, identity.icon),
          Widget.Label({
            css_classes: ["notification-app-name"],
            label: appName,
            xalign: 0,
            hexpand: true,
            ellipsize: Pango.EllipsizeMode.END,
            maxWidthChars: 30,
          }),
          Widget.Label({
            css_classes: ["notification-time"],
            label: relativeTime(sentAt),
            tooltipText: sentAt.toLocaleString(),
          }),
          Widget.Button({
            css_classes: ["notification-close"],
            tooltipText: "Dismiss notification",
            onClicked: () => onDismiss?.(),
            child: Widget.Image({
              iconName: "window-close-symbolic",
              pixelSize: 14,
            }),
          }),
        ],
      }),

      Widget.Label({
        css_classes: ["notification-summary"],
        label: notification.summary || appName,
        xalign: 0,
        wrap: true,
        ellipsize: Pango.EllipsizeMode.END,
        lines: hasBody ? 2 : 5,
        maxWidthChars: 42,
      }),

      hasBody ? Widget.Label({
        css_classes: ["notification-body"],
        label: notification.body,
        xalign: 0,
        wrap: true,
        ellipsize: Pango.EllipsizeMode.END,
        lines: 5,
        maxWidthChars: 42,
        useMarkup: true,
      }) : Widget.Box({ visible: false }),

      progress !== null ? Widget.LevelBar({
        css_classes: ["notification-progress"],
        minValue: 0,
        maxValue: 100,
        value: progress,
        mode: Gtk.LevelBarMode.CONTINUOUS,
        hexpand: true,
        tooltipText: `${progress}%`,
      }) : Widget.Box({ visible: false }),

      image || Widget.Box({ visible: false }),

      validActions.length > 0 ? Widget.Box({
        css_classes: ["notification-actions"],
        spacing: 8,
        vertical: validActions.length > 2,
        homogeneous: true,
        children: validActions.map(action => actionButton(notification, action)),
      }) : Widget.Box({ visible: false }),
    ],
  })

  if (defaultAction) {
    box.add_css_class("notification-actionable")
    box.set_cursor_from_name("pointer")

    const click = new Gtk.GestureClick()
    click.set_button(1)
    click.connect("released", (_gesture, _presses, x, y) => {
      let target = box.pick(x, y, Gtk.PickFlags.DEFAULT)

      // Let close and explicit action buttons handle their own clicks.
      while (target && target !== box) {
        if (target instanceof Gtk.Button) return
        target = target.get_parent()
      }

      notification.invoke(defaultAction.id)
    })
    box.add_controller(click)
  }

  // Keep the existing dismissal behavior for now; timer/hover semantics belong
  // to the notification lifecycle batch rather than this visual pass.
  if (onHoverLost) {
    const motion = new Gtk.EventControllerMotion()
    motion.connect("leave", onHoverLost)
    box.add_controller(motion)
  }

  setup?.()

  return box
}
