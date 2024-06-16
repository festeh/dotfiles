

export function SuspendBlocker() {
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
