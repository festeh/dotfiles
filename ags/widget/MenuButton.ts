import { Widget } from "astal/gtk4"
import { Variable } from "astal"

export default function MenuButton(menuVisible: Variable<boolean>) {
  return Widget.Button({
    css_classes: ["idle-widget"],
    margin: 0,
    child: Widget.Image({
      iconName: "pan-down-symbolic",
      css: "font-size: 18px",
      margin: 0
    }),
    onClicked: () => {
      menuVisible.set(!menuVisible.get())
    },
  })
}
