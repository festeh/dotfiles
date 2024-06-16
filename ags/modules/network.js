const network = await Service.import('network')


export function Network() {
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
