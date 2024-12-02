import { App, Widget, Gtk } from "astal/gtk3";
import AstalTray from "gi://AstalTray?version=0.1";
import { GLib, bind } from "astal";


export default function Tray() {
  const tray = AstalTray.get_default()
  const children = bind(tray, "items").as(items => {
    return items.map(item => {
      if (item.icon_theme_path !== null) {
        App.add_icons(item.icon_theme_path)
      }
      let gicon = item.gicon
      // if (item.title === "yappy2") {
      //   const theme = new Gtk.IconTheme()
      //   theme.set_search_path([item.iconName, item.icon_theme_path])
      //   console.log(theme.get_example_icon_name())
      //   const size = theme.get_icon_sizes(item.icon_theme_path);
      //   // console.log(size, size.length)
      // }

      const menu = item.create_menu()
      // console.log(">", item.title)
      // console.log("name", item.iconName)
      // console.log("path", item.icon_theme_path)
      // console.log("gicon", item.gicon)
      // console.log(item.tooltipMarkup)
      // console.log("----------------------")
      return new Widget.Button({
        tooltipMarkup: bind(item, "tooltipMarkup"),
      }, new Widget.Icon(
        {
          gIcon: gicon
        }
      ))
    })
  })
  return new Widget.Box({
    spacing: 0
  }, children)
}
