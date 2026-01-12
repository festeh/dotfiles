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
  // Check if appIcon is a file path or icon name
  const isFilePath = notification.appIcon?.startsWith("/") || notification.appIcon?.startsWith("~")
  const hasValidIcon = notification.appIcon && notification.appIcon !== ""

  // Check if image is valid (file path exists and is safe)
  const hasValidImage = notification.image &&
                        notification.image.trim() !== "" &&
                        (notification.image.startsWith("/") || notification.image.startsWith("~")) &&
                        !notification.image.includes("..") // Prevent path traversal

  // Filter out invalid/empty actions (must have both label and id, and label must not be empty)
  const validActions = notification.actions?.filter(action => {
    const hasValidLabel = action.label && action.label.trim() !== ""
    const hasValidId = action.id && action.id !== ""
    return hasValidLabel && hasValidId
  }) || []

  const box = Widget.Box({
    css_classes: ["notification"],
    spacing: 12,
    children: [
      // Left side: Icon and/or Image (show both if available, side by side)
      (hasValidIcon || hasValidImage) ? Widget.Box({
        css_classes: ["notification-icons"],
        spacing: 8,
        vertical: false,
        children: [
          // App icon
          hasValidIcon ? Widget.Image({
            css_classes: ["notification-icon"],
            ...(isFilePath
              ? { file: notification.appIcon }
              : { iconName: notification.appIcon }
            ),
          }) : Widget.Box({ visible: false }),

          // Notification image
          hasValidImage ? Widget.Image({
            css_classes: ["notification-image"],
            file: notification.image,
          }) : Widget.Box({ visible: false }),
        ],
      }) : Widget.Box({ visible: false }),

      // Main content area
      Widget.Box({
        css_classes: ["notification-content"],
        vertical: true,
        hexpand: true,
        spacing: 4,
        children: [
          // App name (small, subtle)
          Widget.Label({
            css_classes: ["notification-app-name"],
            label: notification.appName || "Notification",
            xalign: 0,
          }),

          // Summary (main text, bold)
          Widget.Label({
            css_classes: ["notification-summary"],
            label: notification.summary,
            xalign: 0,
            wrap: true,
            maxWidthChars: 35,
          }),

          // Body text (if available)
          notification.body ? Widget.Label({
            css_classes: ["notification-body"],
            label: notification.body,
            xalign: 0,
            wrap: true,
            maxWidthChars: 35,
            useMarkup: true,
          }) : Widget.Box({ visible: false }),

          // Actions (only show valid ones)
          validActions.length > 0 ? Widget.Box({
            css_classes: ["notification-actions"],
            spacing: 8,
            children: validActions.map(action =>
              Widget.Button({
                css_classes: ["notification-action"],
                label: action.label,
                onClicked: () => notification.invoke(action.id),
              })
            ),
          }) : Widget.Box({ visible: false }),
        ],
      }),
    ],
  })

  // Implement GTK4 hover events
  if (onHoverLost) {
    const motion = new Gtk.EventControllerMotion()
    motion.connect("leave", () => {
      onHoverLost()
    })
    box.add_controller(motion)
  }

  if (setup) {
    setup()
  }

  return box
}
