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
import { idle } from "resource:///com/github/Aylur/ags/utils.js";
import Gdk from "gi://Gdk";


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


const Bar = (gdkmonitor) => Widget.Window({
  gdkmonitor,
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
    Bar(monitor),
  ]);
}

async function findMonitor() {
  const hyprland = await Service.import("hyprland")
  let mons = hyprland._monitors
  let allMons = [...mons.values()]
  // find a monitor with DP-3
  let monId = 0
  let eDPMon = allMons.find(mon => mon.name.toLowerCase().includes("dp-3"))
  if (eDPMon) {
    monId = eDPMon.id
    console.log(monId)
  }
  const hyprMon = mons.get(monId)
  const gdkMon = Gdk.Display.get_default()?.get_monitor_at_point(hyprMon.x, hyprMon.y) || null;
  return gdkMon
}

idle(async () => {
  let monitor = await findMonitor()
  addMonitorWindows(monitor);
  addWindows([
    PopupNotification(monitor),
  ]);
  const display = Gdk.Display.get_default();

  display?.connect("monitor-added", (disp, monitor) => {
    addMonitorWindows(monitor);
  });

  display?.connect("monitor-removed", (disp, monitor) => {
    App.windows.forEach(win => {
      App.removeWindow(win);
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

