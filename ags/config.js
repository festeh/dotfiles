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
import { idle, monitorFile } from "resource:///com/github/Aylur/ags/utils.js";
import Gdk from "gi://Gdk";

globalThis.monitorCounter = 0;

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

function addWindows(windows) {
  windows.forEach(win => App.addWindow(win));
}

function addMonitorWindows(monitor) {
  addWindows([
    Bar(),
  ]);
  monitorCounter++;
}

idle(async () => {
  addWindows([
    PopupNotification(),
  ]);

  const display = Gdk.Display.get_default();
  for (let m = 0; m < display?.get_n_monitors(); m++) {
    const monitor = display?.get_monitor(m);
    addMonitorWindows(monitor);
  }

  display?.connect("monitor-added", (disp, monitor) => {
    addMonitorWindows(monitor);
  });

  display?.connect("monitor-removed", (disp, monitor) => {
    App.windows.forEach(win => {
      if (win.gdkmonitor === monitor) App.removeWindow(win);
    });
  });


});
try {
  App.config({
    style: "./style.css",
  })
} catch (e) {
  console.error(e)
  App.quit()
}

export { }

