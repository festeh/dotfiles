import Notifications from "resource:///com/github/Aylur/ags/service/notifications.js";
import {Box, Window} from "resource:///com/github/Aylur/ags/widget.js";
import {lookUpIcon} from "resource:///com/github/Aylur/ags/utils.js";
import GLib from "gi://GLib";
import Pango from "gi://Pango";

const NotificationIcon = notification => {
  let icon;
  if (notification.image) {
    return Widget.Box({
      vexpand: true,
      hexpand: true,
      vpack: "center",
      class_name: "notification-icon",
      css: `background-image: url('${notification.image}');
                  background-size: auto 100%;
                  background-repeat: no-repeat;
                  background-position: center;`,
    });
  } else if (lookUpIcon(notification.app_icon)) icon = notification.app_icon;
  else icon = "user-available-symbolic";
  return Widget.Icon({
    class_name: "notification-icon",
    icon: icon
  });
};

const Notification = notification => Widget.Box({
  class_name: "notification",
  vertical: true,
  children: [
    Widget.EventBox({
      on_primary_click: (box) => {
        // @ts-ignore
        const label = box.child.children[1].children[1];
        if (label.lines < 0) {
          label.lines = 3;
          label.truncate = "end";
        } else {
          label.lines = -1;
          label.truncate = "none";
        }
      },
      child: Widget.Box({
        children: [
          NotificationIcon(notification),
          Widget.Box({
            vertical: true,
            children: [
              Widget.Box({
                children: [
                  Widget.Label({
                    class_name: "notification-title",
                    label: notification.summary,
                    justification: "left",
                    max_width_chars: 180,
                    // truncate: "end",
                    wrap: true,
                    xalign: 0,
                    hexpand: true,
                  }),
                  Widget.Label({
                    class_name: "notification-time",
                    label: GLib.DateTime.new_from_unix_local(notification.time).format("%H:%M"),
                  }),
                  Widget.Button({
                    class_name: "notification-close",
                    child: Widget.Icon("window-close-symbolic"),
                    on_clicked: () => {
                      notification.close();
                    },
                  })
                ]
              }),
              Widget.Label({
                class_name: "notification-body",
                justification: "left",
                max_width_chars: 80,
                lines: 8,
                truncate: "end",
                wrap_mode: Pango.WrapMode.WORD_CHAR,
                xalign: 0,
                wrap: true,
                // HACK: remove linebreaks, so lines property works properly
                label: notification.body.replace(/(\r\n|\n|\r)/gm, " "),
              }),
              notification.hints.value ?
                Widget.ProgressBar({
                  class_name: "notification-progress",
                  value: Number(notification.hints.value.unpack()) / 100
                }) : Widget.Box()
            ]
          })
        ]
      })
    }),
    Widget.Box({
      children: notification.actions.map(action => Widget.Button({
        child: Widget.Label(action.label),
        on_clicked: () => notification.invoke(action.id),
        class_name: "notification-action-button",
        hexpand: true,
      }))
    })
  ]
});
const Popups = () => Box({
  class_name: "spacing-8",
  vertical: true,
  hpack: "end",
  attribute: {
    "map": new Map(),
    /**
     * @param {import('types/widgets/box').default} box
     * @param {number} id
    */
    "dismiss": (box, id) => {
      if (!box.attribute.map.has(id))
        return;
      // const notif = box.attribute.map.get(id);
      // notif.attribute.count--;
      // if (notif.attribute.count <= 0) {
      //   box.attribute.map.delete(id);
      //   notif.attribute.destroyWithAnims();
      // }
    },
    /**
     * @param {import('types/widgets/box').default} box
     * @param {number} id
    */
    "notify": (box, id) => {
      const notif = Notifications.getNotification(id);
      if (Notifications.dnd || !notif)
        return;
      const replace = box.attribute.map.get(id);
      if (!replace) {
        const notification = Notification(notif);
        box.attribute.map.set(id, notification);
        // notification.attribute.count = 1;
        box.pack_start(notification, false, false, 0);
      } else {
        const notification = Notification(notif, true);
        // notification.attribute.count = replace.attribute.count + 1;
        box.remove(replace);
        replace.destroy();
        box.pack_start(notification, false, false, 0);
        box.attribute.map.set(id, notification);
      }
    },
  },
})
  .hook(Notifications, (box, id) => box.attribute.notify(box, id), "notified")
  .hook(Notifications, (box, id) => box.attribute.dismiss(box, id), "dismissed")
  .hook(Notifications, (box, id) => box.attribute.dismiss(box, id), "closed");

const PopupList = () => Box({
  class_name: "notifications-popup-list",
  css: "padding: 10px 5px 10px 10px;",
  children: [
    Popups(),
  ],
});

export default () => Window({
  layer: "overlay",
  name: "popupNotifications",
  anchor: ["top", "right"],
  child: PopupList(),
  visible: false
})
  .hook(Notifications, () => {
    if(Notifications.popups.length > 0) App.openWindow("popupNotifications");
    else App.closeWindow("popupNotifications");
  }, "notify::popups");
