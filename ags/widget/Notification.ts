import { Widget } from "astal/gtk4"
import { Gtk } from "astal/gtk4"
import { bind, Variable } from "astal"
import Notifd from "gi://AstalNotifd"

type NotificationProps = {
  notification: Notifd.Notification
  onHoverLost?: () => void
  setup?: () => void
}

export default function Notification({ notification, onHoverLost, setup }: NotificationProps): Gtk.Widget {
  const box = Widget.Box({
    className: "notification",
    vertical: true,
    children: [
      // Header with app icon, app name, and close button
      Widget.Box({
        className: "notification-header",
        children: [
          Widget.Image({
            className: "notification-app-icon",
            iconName: notification.appIcon || "dialog-information-symbolic",
          }),
          Widget.Label({
            className: "notification-app-name",
            label: notification.appName || "Unknown",
            hexpand: true,
            xalign: 0,
          }),
          Widget.Button({
            className: "notification-close",
            child: Widget.Image({
              iconName: "window-close-symbolic",
            }),
            onClicked: () => notification.dismiss(),
          }),
        ],
      }),

      // Content area with summary and body
      Widget.Box({
        className: "notification-content",
        children: [
          // Image (if available)
          notification.image ? Widget.Box({
            className: "notification-image-container",
            children: [
              Widget.Image({
                className: "notification-image",
                iconName: notification.image,
              }),
            ],
          }) : Widget.Box({ visible: false }),

          // Text content
          Widget.Box({
            className: "notification-text",
            vertical: true,
            hexpand: true,
            children: [
              Widget.Label({
                className: "notification-summary",
                label: notification.summary,
                xalign: 0,
                wrap: true,
                maxWidthChars: 40,
              }),
              notification.body ? Widget.Label({
                className: "notification-body",
                label: notification.body,
                xalign: 0,
                wrap: true,
                maxWidthChars: 40,
                useMarkup: true,
              }) : Widget.Box({ visible: false }),
            ],
          }),
        ],
      }),

      // Actions (if available)
      notification.actions && notification.actions.length > 0 ? Widget.Box({
        className: "notification-actions",
        children: notification.actions.map(action =>
          Widget.Button({
            className: "notification-action",
            child: Widget.Label({
              label: action.label,
            }),
            onClicked: () => notification.invoke(action.id),
          })
        ),
      }) : Widget.Box({ visible: false }),
    ],
  })

  // TODO: Implement GTK4 hover events using GtkEventControllerMotion
  // if (onHoverLost) {
  //   // GTK4: Use event controller instead of leave-notify-event
  // }

  if (setup) {
    setup()
  }

  return box
}
