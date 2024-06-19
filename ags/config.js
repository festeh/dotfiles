import { Motivator } from "./modules/motivator.js"
import { Workspaces } from "./modules/workspaces.js"
import { Pomo } from "./modules/pomo.js"
import { SuspendBlocker } from "./modules/suspend.js"
import { Network } from "./modules/network.js"
import { Volume } from "./modules/volume.js"
import { Battery } from "./modules/battery.js"
import { Clock } from "./modules/clock.js"
import { SysTray } from "./modules/tray.js"

import PopupNotification from "./modules/notifications.js"

import Notifications from "resource:///com/github/Aylur/ags/service/notifications.js";

function Left() {
  return Widget.Box({
    children: [Workspaces()]
  })
}

function Center() {
  return Widget.Box({
    spacing: 8,
    children: [
      Pomo(),
      Motivator(),
    ],
  })
}

function Right() {
  return Widget.Box({
    hpack: "end",
    spacing: 8,
    children: [
      SuspendBlocker(),
      Network(),
      Volume(),
      Battery(),
      Clock(),
      SysTray(),
    ],
  })
}


const Bar = () => Widget.Window({
  name: `bar`,
  anchor: ['top', 'left', 'right'],
  exclusivity: 'exclusive',
  child: Widget.CenterBox({
    startWidget: Left(),
    centerWidget: Center(),
    endWidget: Right(),
  }),
})
Notifications.popupTimeout = 500000000;
Notifications.forceTimeout = false;

try {
  App.config({
    style: "./style.css",
    windows: [
      Bar(),
      PopupNotification(),
    ],
  })
} catch (e) {
  console.error(e)
  App.quit()
}

export { }

