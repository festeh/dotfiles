const hyprland = await Service.import("hyprland")
const systemtray = await Service.import("systemtray")
const audio = await Service.import("audio")
const battery = await Service.import("battery")
const network = await Service.import('network')


const date = Variable("", {
  poll: [1000, 'date "+%H:%M"'],
})

function Workspaces() {
  const activeId = hyprland.active.workspace.bind("id").as(i => i.toString())
  const workspaces = ['1', '2', '3', '4', '5', '6', '7', '8', '9']
  // return Widget.Box({
  //   children: 
  // })
  const widget = Widget.Label({
    label: activeId
  })
  return widget
}

function Left() {
  return Widget.Box({
    children: [Workspaces()]
  })
}

function isOk(data) {
  // try to deserialize the data to json
  try {
    const json = JSON.parse(data)
    const res = json.DmnOn
    if (res === undefined) {
      return false
    }
    return res
  } catch (e) {
    return false
  }
}

function Motivator() {
  const goodIcon = "emblem-favorite-symbolic"
  const badIcon = "face-sad-symbolic"

  const icon = Variable(goodIcon)

  const myLabel = Widget.Icon({
    icon: icon.bind(),
  })

  setInterval(() => {
    try {
      const res = Utils.exec("motivator")
      icon.setValue(isOk(res) ? goodIcon : badIcon)
      myLabel.toggleClassName("blink", !isOk(res))
    } catch (e) {
      icon.setValue(badIcon)
      myLabel.toggleClassName("blink", true)
    }
  }, 3000)

  return myLabel

}

function Center() {
  return Widget.Box({
    children: [
      Motivator(),
    ],
  })
}

function SuspendBlocker() {
  let normalIcon = "emoji-people-symbolic";
  let inhibitIcon = "face-yawn-symbolic";
  let icon = Variable(normalIcon);
  return Widget.ToggleButton({
    onToggled: ({ active }) => {
      if (active) {
        Utils.exec("pkill -9 -f swayidle")
        icon.setValue(inhibitIcon);
      } else {
        icon.setValue(normalIcon);
        print(Utils.execAsync(`bash -c "swayidle -w timeout 1500 'systemctl suspend' &"`))
      }
      print(active);
    },
    child: Widget.Icon({
      icon: icon.bind(),
    }),
  })
}

function Network() {
  const box = Widget.Box({
    children: [
      Widget.Icon({
        icon: network.wifi.bind('icon_name'),
      }),
      // Widget.Label({
      //   label: network.wifi.bind('ssid')
      //     .as(ssid => ssid || 'Unknown'),
      // }),
    ],
  })
  box.toggleClassName('network', true)
  return box
}

function Volume() {
  const icons = {
    101: "overamplified",
    67: "high",
    34: "medium",
    1: "low",
    0: "muted",
  }

  function getIcon() {
    const icon = audio.speaker.is_muted ? 0 : [101, 67, 34, 1, 0].find(
      threshold => threshold <= audio.speaker.volume * 100)

    return `audio-volume-${icons[icon]}-symbolic`
  }

  const icon = Widget.Icon({
    icon: Utils.watch(getIcon(), audio.speaker, getIcon),
  })

  const slider = Widget.Slider({
    hexpand: true,
    draw_value: false,
    on_change: ({ value }) => audio.speaker.volume = value,
    setup: self => self.hook(audio.speaker, () => {
      self.value = audio.speaker.volume || 0
    }),
  })

  return Widget.Box({
    class_name: "volume",
    css: "min-width: 180px",
    children: [icon, slider],
  })
}


function BatteryLabel() {
  const value = battery.bind("percent").as(p => p > 0 ? p / 100 : 0)
  const icon = battery.bind("percent").as(p =>
    `battery-level-${Math.floor(p / 10) * 10}-symbolic`)

  return Widget.Box({
    class_name: "battery",
    visible: battery.bind("available"),
    children: [
      Widget.Icon({ icon }),
      Widget.LevelBar({
        widthRequest: 140,
        vpack: "center",
        value,
      }),
    ],
  })
}

function Clock() {
  return Widget.Label({
    class_name: "clock",
    label: date.bind(),
  })
}

function SysTray() {
  const items = systemtray.bind("items")
    .as(items => items.map(item => Widget.Button({
      child: Widget.Icon({ icon: item.bind("icon") }),
      on_primary_click: (_, event) => item.activate(event),
      on_secondary_click: (_, event) => item.openMenu(event),
      tooltip_markup: item.bind("tooltip_markup"),
    })))

  return Widget.Box({
    children: items,
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
      BatteryLabel(),
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

App.config({
  style: "./style.css",
  windows: [
    Bar(),
  ],
})


hyprland.connect("monitor-added", (_hypr, monitor) => {
  var id = -1
  for (var mt of hyprland.monitors) {
    if (mt.name == monitor)
      id = mt.id
    break;
  }
  id = id == -1 ? 0 : id

  var flag = true
  for (var wd of App.windows) {
    if (wd.name == `bar-${id}`)
      flag = false
    break;
  }

  if (flag)
    App.addWindow(Bar())
})

export { }

